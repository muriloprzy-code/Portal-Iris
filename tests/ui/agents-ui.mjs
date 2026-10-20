// Isolated browser test of the Agents screens (Playwright's bundled Chromium, fresh profile).
// Runs S1..S10 from the Overview simulator, opens each decision in the Decisions drawer and
// checks engine, risk, Gate result, proposal, rationale, evidence and conditions, with no
// browser console errors. Credentials come only from the environment (never the command line).
//
// Env: MYOWN_UI_URL, MYOWN_UI_USER, MYOWN_UI_PASSWORD, MYOWN_UI_OUT (screenshot dir), MYOWN_UI_REPORT (JSON file).
import { chromium } from 'playwright'
import { mkdir, readFile, writeFile } from 'node:fs/promises'
import path from 'node:path'

const baseUrl = (process.env.MYOWN_UI_URL || 'http://localhost:52773/myown/').replace(/\/?$/, '/')
const user = process.env.MYOWN_UI_USER
const password = process.env.MYOWN_UI_PASSWORD
const outDir = process.env.MYOWN_UI_OUT || 'test-results/ui'
const reportPath = process.env.MYOWN_UI_REPORT || 'test-results/agents-ui.json'
if (!user || !password) {
  console.error('MYOWN_UI_USER and MYOWN_UI_PASSWORD are required.')
  process.exit(2)
}
const apiRoot = new URL('/myown/api', baseUrl).toString()
const basic = 'Basic ' + Buffer.from(`${user}:${password}`).toString('base64')

// Expected drawer content per scenario with the deterministic Rules engine.
const expected = {
  S1: { risk: 'critical', action: 'notify', proposal: false, evidence: true, conditions: false },
  S2: { risk: 'critical', action: 'propose_task_suspend', proposal: true, evidence: true, conditions: false },
  S3: { risk: 'warning', action: 'propose_task_resume', proposal: true, evidence: true, conditions: false },
  S4: { risk: 'info', action: 'ignore', proposal: false, evidence: false, conditions: false },
  S5: { risk: 'low', action: 'approve', proposal: true, evidence: true, conditions: true },
  S6: { risk: 'high', action: 'escalate', proposal: false, evidence: true, conditions: false },
  S7: { risk: 'high', action: 'escalate', proposal: false, evidence: true, conditions: false, gate: ['blocked', 'prohibited-target'] },
  S8: { risk: 'warning', action: 'notify', proposal: false, evidence: true, conditions: false },
  S9: { risk: 'high', action: 'escalate', proposal: false, evidence: true, conditions: false },
  S10: { risk: 'warning', action: 'notify', proposal: false, evidence: true, conditions: false, outcome: 'budget_blocked' },
}

const results = []
const consoleErrors = []
const serverErrors = []
const createdProposals = []
const startedAt = new Date().toISOString()
const add = (id, passed, details) => {
  results.push({ id, status: passed ? 'pass' : 'fail', details })
  console.log(`${passed ? 'PASS' : 'FAIL'}  ${id}  ${details}`)
}

async function api(method, route, body) {
  const response = await fetch(`${apiRoot}${route}`, {
    method,
    headers: { Authorization: basic, 'X-MyOwn-SysAdmin-Authorization': basic, 'Content-Type': 'application/json' },
    body: body ? JSON.stringify(body) : undefined,
  })
  return response.json()
}

async function openTab(page, name) {
  await page.getByRole('tab', { name, exact: true }).click()
}

async function setSettings(page, values) {
  await openTab(page, 'Settings')
  for (const [label, checked] of Object.entries(values)) {
    await page.getByLabel(label, { exact: true }).setChecked(checked)
  }
  await page.getByRole('button', { name: 'Save settings' }).click()
  await page.getByText('Agent settings were saved and audited.').waitFor()
}

const ddFor = (drawer, label) => drawer.locator('dt', { hasText: new RegExp(`^${label}$`) }).locator('xpath=following-sibling::dd[1]')

await mkdir(outDir, { recursive: true })
const browser = await chromium.launch()
const context = await browser.newContext({ viewport: { width: 1440, height: 900 } })
const page = await context.newPage()
page.on('console', (message) => { if (message.type() === 'error') consoleErrors.push(message.text()) })
page.on('pageerror', (error) => consoleErrors.push(`pageerror: ${error.message}`))
page.on('response', (response) => { if (response.url().includes('/myown/api/') && response.status() >= 500) serverErrors.push(`${response.status()} ${response.url()}`) })

let original = null
try {
  await page.goto(baseUrl)
  await page.locator('#username').fill(user)
  await page.locator('#password').fill(password)
  await page.getByRole('button', { name: 'Sign in' }).click()
  await page.getByRole('navigation', { name: 'Main navigation' }).getByRole('button', { name: /Agents/ }).click()
  await page.getByRole('tab', { name: 'Overview', exact: true }).waitFor()

  const config = (await api('GET', '/agent/config')).data
  original = { 'Demo mode': Boolean(Number(config.demoMode)), 'Read-only mode': Boolean(Number(config.readOnly)) }
  if (Number(config.killSwitch)) throw new Error('The kill switch is on; turn it off before running the UI test.')
  await setSettings(page, { 'Demo mode': true, 'Read-only mode': false })
  add('UI-SETTINGS', true, 'Demo mode enabled and read-only disabled through the Settings screen.')

  for (const [scenario, want] of Object.entries(expected)) {
    await openTab(page, 'Overview')
    await page.getByLabel('Demonstration scenario').selectOption(scenario)
    const simulateResponse = page.waitForResponse((response) => response.url().endsWith('/agent/simulate') && response.request().method() === 'POST')
    await page.getByRole('button', { name: 'Run scenario' }).click()
    const simulateHttp = await simulateResponse
    const sentTaskId = Number(JSON.parse(simulateHttp.request().postData() || '{}').taskId || 0)
    const simulation = await simulateHttp.json()
    const data = simulation.data
    if (!data) {
      add(`UI-${scenario}`, false, `The screen could not run the scenario: ${JSON.stringify(simulation.error ?? simulation)}`)
      await page.screenshot({ path: path.join(outDir, `${scenario}-error.png`), fullPage: true })
      continue
    }
    await page.getByText(`${scenario} completed through the interoperability production.`).waitFor()
    if (data.proposalId) createdProposals.push(data.proposalId)

    await openTab(page, 'Decisions')
    const openButton = page.getByRole('button', { name: `Open decision ${data.decisionId}`, exact: true })
    await openButton.waitFor()
    await openButton.click()
    const drawer = page.getByRole('dialog')
    await drawer.getByRole('heading', { name: data.decision.action }).waitFor()

    const engine = (await ddFor(drawer, 'Engine').innerText()).trim()
    const risk = (await ddFor(drawer, 'Risk').innerText()).trim()
    const gate = (await ddFor(drawer, 'Gate').innerText()).trim()
    const proposal = (await ddFor(drawer, 'Proposal').innerText()).trim()
    const rationale = (await drawer.locator('h4:has-text("Rationale") + p').innerText()).trim()
    const evidence = await drawer.locator('h4:has-text("Evidence") + ul > li').count()
    const conditions = await drawer.locator('h4:has-text("Conditions") + ul > li').count()
    const htmlInText = await drawer.locator('.decision-text script, ul script').count()
    await page.screenshot({ path: path.join(outDir, `${scenario}-decision.png`) })

    const problems = []
    if (engine !== 'rules') problems.push(`engine=${engine}`)
    if (risk !== want.risk) problems.push(`risk=${risk}`)
    if (!gate.startsWith(`final action ${want.action}`)) problems.push(`gate=${gate}`)
    for (const fragment of want.gate ?? []) if (!gate.includes(fragment)) problems.push(`gate lacks ${fragment}`)
    if (want.proposal !== /^#\d+ .* pending$/.test(proposal)) problems.push(`proposal=${proposal}`)
    if (!rationale || rationale === '—') problems.push('rationale empty')
    if (want.evidence !== evidence > 0) problems.push(`evidence=${evidence}`)
    if (want.conditions !== conditions > 0) problems.push(`conditions=${conditions}`)
    if (want.outcome && data.outcome !== want.outcome) problems.push(`outcome=${data.outcome}`)
    // The screen itself must pick the demonstration task (not rely on the server fallback).
    if (['S2', 'S3'].includes(scenario) && !(sentTaskId > 0 && String(data.decision.targetId) === String(sentTaskId))) problems.push(`screen sent taskId=${sentTaskId}`)
    if (htmlInText) problems.push('model text rendered as HTML')
    add(`UI-${scenario}`, problems.length === 0, `decision ${data.decisionId}${sentTaskId ? ` (taskId ${sentTaskId} sent by the screen)` : ''}: engine ${engine}; risk ${risk}; gate "${gate}"; proposal "${proposal}"; rationale ${rationale.length} chars; evidence ${evidence}; conditions ${conditions}${problems.length ? ` | ${problems.join(', ')}` : ''}`)

    await page.keyboard.press('Escape')
    const closed = await drawer.waitFor({ state: 'detached', timeout: 3000 }).then(() => true, () => false)
    if (!closed) add(`UI-${scenario}-CLOSE`, false, 'Escape did not close the decision drawer.')
  }
} catch (error) {
  add('UI-RUN', false, `Unexpected failure: ${error.message}`)
  await page.screenshot({ path: path.join(outDir, 'failure.png'), fullPage: true }).catch(() => {})
} finally {
  for (const id of createdProposals) await api('POST', `/agent/proposals/${id}/reject`, { reason: 'UI test cleanup' }).catch(() => {})
  if (original) {
    try {
      await setSettings(page, original)
    } catch (error) {
      await api('PUT', '/agent/config', { demoMode: original['Demo mode'], readOnly: original['Read-only mode'] }).catch(() => {})
      add('UI-RESTORE', false, `Settings were restored through REST after the screen failed: ${error.message}`)
    }
  }
  add('UI-CONSOLE', consoleErrors.length === 0, consoleErrors.length ? `Console errors: ${consoleErrors.join(' | ')}` : 'No browser console errors.')
  add('UI-SERVER', serverErrors.length === 0, serverErrors.length ? `Server errors: ${serverErrors.join(' | ')}` : 'No HTTP 5xx responses from /myown/api.')
  await browser.close()
}

const pass = results.filter((item) => item.status === 'pass').length
const fail = results.length - pass
const playwrightVersion = JSON.parse(await readFile(new URL('./node_modules/playwright/package.json', import.meta.url), 'utf8')).version
await writeFile(reportPath, JSON.stringify({ suite: 'agents-ui', startedAt, finishedAt: new Date().toISOString(), browser: `chromium (playwright ${playwrightVersion})`, baseUrl, screenshots: outDir, results, summary: { pass, fail, skip: 0 } }, null, 2))
console.log(`agents-ui: ${pass} passed, ${fail} failed. Report written to ${reportPath}`)
process.exit(fail ? 1 : 0)
