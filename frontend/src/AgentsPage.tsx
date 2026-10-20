import { type FormEvent, useCallback, useEffect, useRef, useState } from 'react'
import {
  confirmAgentProposal,
  controlAgentProduction,
  getAgentAccessRequests,
  getAgentConfig,
  getAgentDecision,
  getAgentDecisions,
  getAgentGuardrails,
  getAgentLedgerSummary,
  getAgentProduction,
  getAgentProposals,
  getAgentStatus,
  getAgentTrace,
  rejectAgentProposal,
  setAgentKillSwitch,
  simulateAgentScenario,
  submitAgentAccessRequest,
  updateAgentConfig,
  type AgentAccessRequest,
  type AgentConfig,
  type AgentDecision,
  type AgentEvidence,
  type AgentGuardrails,
  type AgentLedgerSummary,
  type AgentProduction,
  type AgentProposal,
  type AgentSimulation,
  type AgentStatus,
  type AgentTrace,
} from './api/client'

type AgentsPageProps = { canManage: boolean }
type AgentTab = 'Overview' | 'Decisions' | 'Approvals' | 'Access' | 'Observability' | 'Production' | 'Guardrails' | 'Settings'

const allTabs: AgentTab[] = ['Overview', 'Decisions', 'Approvals', 'Access', 'Observability', 'Production', 'Guardrails', 'Settings']
const administratorTabs = new Set<AgentTab>(['Approvals', 'Production', 'Settings'])
const scenarios = Array.from({ length: 10 }, (_, index) => `S${index + 1}`)
const yes = (value: boolean | number | undefined) => Boolean(Number(value))

function display(value: unknown) {
  if (value === null || value === undefined || value === '') return '—'
  if (typeof value === 'object') return JSON.stringify(value)
  return String(value)
}

export default function AgentsPage({ canManage }: AgentsPageProps) {
  const tabs = canManage ? allTabs : allTabs.filter((tab) => !administratorTabs.has(tab))
  const [activeTab, setActiveTab] = useState<AgentTab>('Overview')
  const [status, setStatus] = useState<AgentStatus | null>(null)
  const [config, setConfig] = useState<AgentConfig | null>(null)
  const [decisions, setDecisions] = useState<AgentDecision[]>([])
  const [proposals, setProposals] = useState<AgentProposal[]>([])
  const [requests, setRequests] = useState<AgentAccessRequest[]>([])
  const [ledger, setLedger] = useState<AgentLedgerSummary | null>(null)
  const [production, setProduction] = useState<AgentProduction | null>(null)
  const [guardrails, setGuardrails] = useState<AgentGuardrails | null>(null)
  const [trace, setTrace] = useState<AgentTrace | null>(null)
  const [selectedDecision, setSelectedDecision] = useState<AgentDecision | null>(null)
  const [scenario, setScenario] = useState('S1')
  const [simulation, setSimulation] = useState<AgentSimulation | null>(null)
  const [role, setRole] = useState('MyOwnViewer')
  const [justification, setJustification] = useState('Temporary access required for portal operations.')
  const [busy, setBusy] = useState('')
  const [error, setError] = useState('')
  const [notice, setNotice] = useState('')

  const refresh = useCallback(async () => {
    setError('')
    try {
      const [statusResponse, decisionsResponse, requestsResponse, ledgerResponse, productionResponse, guardrailsResponse] = await Promise.all([
        getAgentStatus(), getAgentDecisions(), getAgentAccessRequests(), getAgentLedgerSummary(), getAgentProduction(), getAgentGuardrails(),
      ])
      setStatus(statusResponse.data)
      setDecisions(decisionsResponse.data)
      setRequests(requestsResponse.data)
      setLedger(ledgerResponse.data)
      setProduction(productionResponse.data)
      setGuardrails(guardrailsResponse.data)
      if (canManage) {
        const [configResponse, proposalsResponse] = await Promise.all([getAgentConfig(), getAgentProposals()])
        setConfig(configResponse.data)
        setProposals(proposalsResponse.data)
      }
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Agent information could not be loaded.')
    }
  }, [canManage])

  useEffect(() => {
    refresh()
    const interval = window.setInterval(refresh, 15_000)
    return () => window.clearInterval(interval)
  }, [refresh])

  // Access requests are decided asynchronously by the production; poll briefly while any is queued.
  const hasQueuedRequest = requests.some((item) => item.status === 'queued')
  useEffect(() => {
    if (!hasQueuedRequest) return
    const interval = window.setInterval(async () => {
      try {
        const response = await getAgentAccessRequests()
        setRequests(response.data)
      } catch {
        // The 15-second refresh reports errors; a failed poll is retried on the next tick.
      }
    }, 2_000)
    return () => window.clearInterval(interval)
  }, [hasQueuedRequest])

  async function runAction(name: string, action: () => Promise<void>, success: string) {
    setBusy(name)
    setError('')
    setNotice('')
    try {
      await action()
      setNotice(success)
      await refresh()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'The action could not be completed.')
    } finally {
      setBusy('')
    }
  }

  function handleSimulation() {
    return runAction('simulate', async () => {
      const response = await simulateAgentScenario(scenario)
      setSimulation(response.data)
    }, `${scenario} completed through the interoperability production.`)
  }

  function handleAccessRequest(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    return runAction('access', async () => { await submitAgentAccessRequest(role, justification) }, 'The access request was queued. The agent decision appears here when the production finishes.')
  }

  function handleSaveConfig(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    if (!config) return
    return runAction('config', async () => {
      const response = await updateAgentConfig(config)
      setConfig(response.data)
    }, 'Agent settings were saved and audited.')
  }

  async function openDecision(id: number) {
    setBusy(`decision-${id}`)
    setError('')
    try {
      const response = await getAgentDecision(id)
      setSelectedDecision(response.data)
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'The decision could not be loaded.')
    } finally {
      setBusy('')
    }
  }

  async function openTrace(traceId: string) {
    setBusy(`trace-${traceId}`)
    setError('')
    try {
      const response = await getAgentTrace(traceId)
      setTrace(response.data)
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'The trace could not be loaded.')
    } finally {
      setBusy('')
    }
  }

  return (
    <section className="agents-page">
      <div className="page-intro agents-intro">
        <div><p className="eyebrow">SAFE AGENT OPERATIONS</p><h2>AI decisions inside Interoperability</h2><p>Review every decision, approval and trace while deterministic guardrails keep state changes under human control.</p></div>
        <div className="agent-hero-status">
          <span className={`agent-orb ${status?.activeEngine === 'aihub' ? 'aihub' : ''}`}>✦</span>
          <div><small>ACTIVE ENGINE</small><strong>{status?.activeEngine === 'aihub' ? 'IRIS AI Hub' : 'Rules engine'}</strong><p>{yes(status?.production.running) ? 'Production running' : 'Production stopped'}</p></div>
        </div>
      </div>

      <div className="data-panel agents-panel">
        <div className="data-toolbar agent-toolbar">
          <div className="tabs agent-tabs" role="tablist" aria-label="Agent management">
            {tabs.map((tab) => <button role="tab" aria-selected={activeTab === tab} className={activeTab === tab ? 'active' : ''} type="button" key={tab} onClick={() => setActiveTab(tab)}>{tab}{tab === 'Approvals' && proposals.filter((item) => item.state === 'pending').length > 0 && <b>{proposals.filter((item) => item.state === 'pending').length}</b>}</button>)}
          </div>
          <button className="row-action" type="button" onClick={refresh} disabled={Boolean(busy)}>Refresh</button>
        </div>

        {(error || notice) && <div className={`agent-banner ${error ? 'error' : ''}`} role={error ? 'alert' : 'status'}>{error || notice}</div>}

        {activeTab === 'Overview' && <div className="agent-content">
          <div className="agent-stat-grid">
            <article><small>ENGINE</small><strong>{status?.activeEngine ?? '—'}</strong><p>{yes(status?.aiHubAvailable) ? 'AI Hub module available' : 'Rules fallback available'}</p></article>
            <article><small>DECISIONS</small><strong>{ledger?.decisions ?? '—'}</strong><p>Recorded in the audit ledger</p></article>
            <article><small>PENDING</small><strong>{canManage ? proposals.filter((item) => item.state === 'pending').length : 'Protected'}</strong><p>Human confirmation required</p></article>
            <article><small>TOKEN BUDGET</small><strong>{status ? `${status.tokensUsedToday}/${status.dailyTokenBudget}` : '—'}</strong><p>Used today</p></article>
          </div>
          {canManage && <div className="agent-simulator">
            <div><p className="eyebrow">DEMONSTRATION</p><h3>Run a deterministic scenario</h3><p>The event follows the real Business Service → Business Process → Business Operation flow.</p></div>
            <div className="agent-action-line"><select aria-label="Demonstration scenario" value={scenario} onChange={(event) => setScenario(event.target.value)}>{scenarios.map((item) => <option key={item}>{item}</option>)}</select><button type="button" onClick={handleSimulation} disabled={busy === 'simulate' || !yes(config?.demoMode)}>{busy === 'simulate' ? 'Running…' : 'Run scenario'}</button></div>
            {!yes(config?.demoMode) && <small className="agent-help">Enable Demo mode in Settings to use the built-in scenarios.</small>}
            {simulation && <div className="simulation-result"><span className="status-chip enabled">{simulation.outcome}</span><strong>{display(simulation.decision?.action)}</strong><p>Engine: {simulation.engine} · Trace: {simulation.traceId}</p><button className="row-action" type="button" onClick={() => openTrace(simulation.traceId)}>Open trace</button></div>}
          </div>}
        </div>}

        {activeTab === 'Decisions' && <>
          <div className="table-wrap"><table><thead><tr><th>ID</th><th>Workflow</th><th>Action</th><th>Engine</th><th>Risk</th><th>Confidence</th><th>Validation</th><th>Proposal</th><th>When</th><th>Details</th></tr></thead><tbody>{decisions.map((item) => <tr key={item.id} className={selectedDecision?.id === item.id ? 'selected-row' : undefined}><td className="mono">{item.id}</td><td>{item.workflow}</td><td className="primary-cell">{item.action}</td><td><span className="status-chip enabled">{item.engine}</span></td><td>{item.riskLevel || item.severity || '—'}</td><td>{Math.round(Number(item.confidence || 0) * 100)}%</td><td>{item.validationStatus}</td><td>{item.proposalId ? `#${item.proposalId}` : '—'}</td><td>{item.decidedAt}</td><td><button className="row-action" type="button" onClick={() => openDecision(item.id)} disabled={busy === `decision-${item.id}`} aria-label={`Open decision ${item.id}`}>Open</button></td></tr>)}{!decisions.length && <tr><td className="empty-row" colSpan={10}>No agent decisions have been recorded yet.</td></tr>}</tbody></table></div>
          {selectedDecision && <DecisionDrawer decision={selectedDecision} onClose={() => setSelectedDecision(null)} onOpenTrace={(traceId) => { setActiveTab('Observability'); void openTrace(traceId) }} />}
        </>}

        {activeTab === 'Approvals' && canManage && <div className="agent-card-list">{proposals.map((item) => <article key={item.id}><div className="agent-card-heading"><div><small>PROPOSAL #{item.id}</small><h3>{item.kind}</h3></div><span className={`status-chip ${item.state === 'pending' ? 'warning' : item.state === 'executed' ? 'enabled' : ''}`}>{item.state}</span></div><dl><div><dt>Target</dt><dd>{item.targetType}: {item.targetId}</dd></div><div><dt>Expires</dt><dd>{item.expiresAt}</dd></div><div><dt>Required privilege</dt><dd>{item.requiredPrivilege || '—'}</dd></div><div><dt>Undo</dt><dd>{item.undoHint || '—'}</dd></div></dl>{item.resultMessage && <p>{item.resultMessage}</p>}{item.state === 'pending' && <div className="agent-card-actions"><button type="button" onClick={() => runAction(`confirm-${item.id}`, async () => { await confirmAgentProposal(item.id) }, `Proposal #${item.id} was confirmed and verified.`)} disabled={Boolean(busy)}>Confirm</button><button className="danger" type="button" onClick={() => runAction(`reject-${item.id}`, async () => { await rejectAgentProposal(item.id, 'Rejected by the administrator in MyOwn Portal.') }, `Proposal #${item.id} was rejected.`)} disabled={Boolean(busy)}>Reject</button></div>}</article>)}{!proposals.length && <div className="data-state">No proposals have been created.</div>}</div>}

        {activeTab === 'Access' && <div className="agent-content two-column-agent"><form className="agent-form" onSubmit={handleAccessRequest}><p className="eyebrow">NEW REQUEST</p><h3>Request an IRIS role</h3><label>Role<input value={role} onChange={(event) => setRole(event.target.value)} maxLength={160} required /></label><label>Business justification<textarea value={justification} onChange={(event) => setJustification(event.target.value)} maxLength={500} required /></label><button type="submit" disabled={busy === 'access'}>{busy === 'access' ? 'Submitting…' : 'Submit for analysis'}</button><small>{justification.length}/500 characters</small></form><div className="agent-card-list compact">{requests.map((item) => <article key={item.id}><div className="agent-card-heading"><div><small>REQUEST #{item.id}</small><h3>{item.roleRequested}</h3></div><span className={`status-chip ${item.status === 'decided' ? 'enabled' : item.status === 'queued' ? 'warning' : ''}`}>{item.status}</span></div><p>{item.justification}</p>{item.recommendation && <p>Agent recommendation: <b>{item.recommendation}</b>{item.riskLevel ? ` · risk ${item.riskLevel}` : ''}{item.proposalId ? ` · proposal #${item.proposalId}` : ''}</p>}<small>{item.requester} · {item.createdAt}</small></article>)}{!requests.length && <div className="data-state">No access requests are visible to this account.</div>}</div></div>}

        {activeTab === 'Observability' && <div className="agent-content"><div className="agent-stat-grid"><article><small>DECISIONS</small><strong>{ledger?.decisions ?? 0}</strong><p>Total recorded calls</p></article><article><small>TOKENS</small><strong>{ledger?.totalTokens ?? 0}</strong><p>Prompt and completion tokens</p></article><article><small>ESTIMATED COST</small><strong>${Number(ledger?.costEstimateUSD ?? 0).toFixed(4)}</strong><p>Based on the pricing table</p></article><article><small>AVG. LATENCY</small><strong>{Math.round(Number(ledger?.averageDurationMs ?? 0))} ms</strong><p>End-to-end decision time</p></article></div>{trace && <TracePanel trace={trace} onClose={() => setTrace(null)} />}{!trace && <div className="agent-empty"><span>◎</span><h3>Select “View” on a decision</h3><p>The complete event, decision and ledger timeline will appear here.</p></div>}</div>}

        {activeTab === 'Production' && canManage && <div className="agent-content"><div className="production-control"><div><p className="eyebrow">INTEROPERABILITY</p><h3>{production?.name || 'MyOwn.Production.Main'}</h3><p>{yes(production?.running) ? 'The agent workflow is receiving and processing events.' : 'The workflow is currently stopped.'}</p></div><button className={yes(production?.running) ? 'danger' : ''} type="button" disabled={busy === 'production'} onClick={() => runAction('production', async () => { const response = await controlAgentProduction(yes(production?.running) ? 'stop' : 'start'); setProduction(response.data) }, `Production ${yes(production?.running) ? 'stopped' : 'started'}.`)}>{yes(production?.running) ? 'Stop production' : 'Start production'}</button></div><div className="table-wrap"><table><thead><tr><th>Item</th><th>Class</th><th>Enabled</th></tr></thead><tbody>{production?.items.map((item) => <tr key={item.name}><td className="primary-cell">{item.name}</td><td>{item.className}</td><td><span className={`status-chip ${yes(item.enabled) ? 'enabled' : ''}`}>{yes(item.enabled) ? 'Yes' : 'No'}</span></td></tr>)}</tbody></table></div></div>}

        {activeTab === 'Guardrails' && <div className="agent-content"><div className="guardrail-grid"><Guardrail title="Human confirmation" enabled={guardrails?.stateChangesRequireConfirmation} text="Every state change becomes a proposal first." /><Guardrail title="Read-only tools" enabled={guardrails?.agentToolsAreReadOnly} text="The agent can inspect data but cannot execute changes." /><Guardrail title="Untrusted output" enabled={guardrails?.modelOutputIsUntrusted} text="Every model response is validated before use." /><Guardrail title="Separation of duties" enabled={guardrails?.separationOfDuties} text="A requester cannot approve the same access request." /></div><div className="guardrail-lists"><article><h3>Data allowed for analysis</h3>{guardrails?.sentToModel.map((item) => <p key={item}>✓ {item}</p>)}</article><article><h3>Data that never leaves IRIS</h3>{guardrails?.neverSentToModel.map((item) => <p key={item}>⊘ {item}</p>)}</article></div></div>}

        {activeTab === 'Settings' && canManage && config && <form className="agent-content agent-settings" onSubmit={handleSaveConfig}><div className="settings-heading"><div><p className="eyebrow">ADMINISTRATOR SETTINGS</p><h3>Agent runtime</h3><p>API keys are supplied through the server environment and are never stored here.</p></div><button className={`kill-switch ${yes(config.killSwitch) ? 'danger' : ''}`} type="button" onClick={() => runAction('kill', async () => { const response = await setAgentKillSwitch(!yes(config.killSwitch)); setConfig(response.data) }, `Kill switch ${yes(config.killSwitch) ? 'disabled' : 'enabled'}.`)}>{yes(config.killSwitch) ? 'Disable kill switch' : 'Enable kill switch'}</button></div><div className="settings-grid"><label>Engine preference<select value={config.enginePreference} onChange={(event) => setConfig({ ...config, enginePreference: event.target.value as AgentConfig['enginePreference'] })}><option value="auto">Automatic</option><option value="rules">Rules only</option><option value="aihub">AI Hub</option></select></label><label>Provider<input value={config.provider} onChange={(event) => setConfig({ ...config, provider: event.target.value })} /></label><label>Model<input value={config.model} onChange={(event) => setConfig({ ...config, model: event.target.value })} placeholder="Configured model" /></label><label>Daily token budget<input type="number" min="0" value={config.dailyTokenBudget} onChange={(event) => setConfig({ ...config, dailyTokenBudget: Number(event.target.value) })} /></label><label>Per-decision budget<input type="number" min="0" value={config.perDecisionTokenBudget} onChange={(event) => setConfig({ ...config, perDecisionTokenBudget: Number(event.target.value) })} /></label><label>Cooldown (minutes)<input type="number" min="0" value={config.cooldownMinutes} onChange={(event) => setConfig({ ...config, cooldownMinutes: Number(event.target.value) })} /></label><label>Calls per hour<input type="number" min="1" value={config.maxAgentCallsPerHour} onChange={(event) => setConfig({ ...config, maxAgentCallsPerHour: Number(event.target.value) })} /></label><label>Proposal lifetime (minutes)<input type="number" min="1" value={config.proposalTTLMinutes} onChange={(event) => setConfig({ ...config, proposalTTLMinutes: Number(event.target.value) })} /></label></div><div className="settings-checks"><label><input type="checkbox" checked={yes(config.demoMode)} onChange={(event) => setConfig({ ...config, demoMode: event.target.checked })} /> Demo mode</label><label><input type="checkbox" checked={yes(config.readOnly)} onChange={(event) => setConfig({ ...config, readOnly: event.target.checked })} /> Read-only mode</label><span>Provider key: {yes(config.apiKeyConfigured) ? 'configured' : 'not configured'}</span></div><button className="state-action" type="submit" disabled={busy === 'config'}>{busy === 'config' ? 'Saving…' : 'Save settings'}</button></form>}
      </div>
    </section>
  )
}

function Guardrail({ title, enabled, text }: { title: string; enabled: boolean | number | undefined; text: string }) {
  return <article><span>{yes(enabled) ? '✓' : '!'}</span><div><h3>{title}</h3><p>{text}</p></div></article>
}

function evidenceLabel(item: AgentEvidence) {
  return `${item.source || 'evidence'}: ${display(item.ref)}`
}

function gateSummary(decision: AgentDecision) {
  const gate = decision.gate
  if (!gate) return '—'
  const parts = [`final action ${gate.finalAction || decision.action}`]
  parts.push(gate.downgradedBy ? `downgraded by ${gate.downgradedBy}` : 'no downgrade')
  if (gate.allowed !== undefined) parts.push(yes(gate.allowed) ? 'allowed' : 'blocked')
  return parts.join(' · ')
}

/**
 * Decision details. Rationale, evidence and conditions come from the model (sanitized by the
 * server) and are rendered only as React text nodes, never as HTML.
 */
function DecisionDrawer({ decision, onClose, onOpenTrace }: { decision: AgentDecision; onClose: () => void; onOpenTrace: (traceId: string) => void }) {
  const closeButton = useRef<HTMLButtonElement>(null)
  const latestOnClose = useRef(onClose)
  useEffect(() => { latestOnClose.current = onClose }, [onClose])
  // Focus only when another decision opens; the page refreshes every 15 s and must not steal focus.
  useEffect(() => { closeButton.current?.focus() }, [decision.id])
  useEffect(() => {
    const onKey = (event: KeyboardEvent) => { if (event.key === 'Escape') latestOnClose.current() }
    window.addEventListener('keydown', onKey)
    return () => window.removeEventListener('keydown', onKey)
  }, [])

  const evidence = decision.evidence ?? []
  const conditions = decision.conditions ?? []
  return <aside className="decision-drawer" role="dialog" aria-modal="false" aria-labelledby="decision-drawer-title">
    <div className="agent-card-heading"><div><small>DECISION #{decision.id} · {decision.workflow}</small><h3 id="decision-drawer-title">{decision.action}</h3></div><button ref={closeButton} className="row-action" type="button" onClick={onClose}>Close</button></div>
    <dl>
      <div><dt>Engine</dt><dd>{decision.engine}</dd></div>
      <div><dt>Risk</dt><dd>{decision.riskLevel || decision.severity || '—'}</dd></div>
      <div><dt>Validation</dt><dd>{decision.validationStatus}</dd></div>
      <div><dt>Confidence</dt><dd>{Math.round(Number(decision.confidence || 0) * 100)}%</dd></div>
      <div className="wide"><dt>Gate</dt><dd>{gateSummary(decision)}{decision.gate?.reason ? ` · ${decision.gate.reason}` : ''}</dd></div>
      <div className="wide"><dt>Proposal</dt><dd>{decision.proposal ? `#${decision.proposal.id} · ${decision.proposal.kind} · ${decision.proposal.state}` : 'No proposal was created.'}</dd></div>
    </dl>
    <h4>Rationale</h4>
    <p className="decision-text">{decision.rationale || '—'}</p>
    <h4>Evidence</h4>
    {evidence.length ? <ul>{evidence.map((item, index) => <li key={index}>{evidenceLabel(item)}</li>)}</ul> : <p className="decision-text">—</p>}
    <h4>Conditions</h4>
    {conditions.length ? <ul>{conditions.map((item, index) => <li key={index}>{item}</li>)}</ul> : <p className="decision-text">—</p>}
    <button className="row-action" type="button" onClick={() => onOpenTrace(decision.traceId)}>View trace</button>
  </aside>
}

function TracePanel({ trace, onClose }: { trace: AgentTrace; onClose: () => void }) {
  return <div className="trace-panel"><div className="agent-card-heading"><div><small>TRACE</small><h3>{trace.traceId}</h3></div><button className="row-action" type="button" onClick={onClose}>Close</button></div><ol>{trace.timeline.map((item, index) => <li key={`${item.type}-${display(item.id)}-${index}`}><span>{index + 1}</span><div><strong>{item.type}</strong><small>{display(item.at)}</small><p>{Object.entries(item).filter(([key]) => !['type', 'at'].includes(key)).map(([key, value]) => `${key}: ${display(value)}`).join(' · ')}</p></div></li>)}</ol></div>
}
