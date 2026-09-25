import { type FormEvent, useEffect, useState } from 'react'
import { clearCredentials, getHealth, getHealthReport, getProcesses, getSession, getSystemSummary, setCredentials, type HealthReportResponse, type HealthResponse, type ProcessItem, type SystemSummaryResponse } from './api/client'
import PermissionsPage from './PermissionsPage'
import ApplicationsPage from './ApplicationsPage'
import TasksPage from './TasksPage'
import LogsPage from './LogsPage'
import SecurityPage from './SecurityPage'

const sections = ['Overview', 'Permissions', 'Applications & APIs', 'Security', 'Tasks', 'Logs']

const icons = ['⌂', '♙', '⌘', '◇', '◷', '≡']

export default function App() {
  const [health, setHealth] = useState<HealthResponse | null>(null)
  const [summary, setSummary] = useState<SystemSummaryResponse | null>(null)
  const [healthReport, setHealthReport] = useState<HealthReportResponse | null>(null)
  const [processes, setProcesses] = useState<ProcessItem[]>([])
  const [processError, setProcessError] = useState('')
  const [username, setUsername] = useState('')
  const [password, setPassword] = useState('')
  const [currentUser, setCurrentUser] = useState('')
  const [error, setError] = useState('')
  const [isSubmitting, setIsSubmitting] = useState(false)
  const [activeSection, setActiveSection] = useState('Overview')
  const [accessLevel, setAccessLevel] = useState<'Administrator' | 'Viewer' | 'None'>('None')
  const canManage = accessLevel === 'Administrator'
  const visibleSections = canManage ? sections : sections.filter((section) => section !== 'Permissions' && section !== 'Security')

  useEffect(() => {
    const handleUnauthorized = () => {
      clearCredentials()
      setCurrentUser('')
      setHealth(null)
      setSummary(null)
      setHealthReport(null)
      setProcesses([])
      setProcessError('')
      setPassword('')
      setError('Your session has expired. Please sign in again.')
      setAccessLevel('None')
    }

    window.addEventListener('myown:unauthorized', handleUnauthorized)
    return () => window.removeEventListener('myown:unauthorized', handleUnauthorized)
  }, [])

  useEffect(() => {
    if (!currentUser) return
    const refresh = () => {
      getSystemSummary().then(setSummary).catch(() => undefined)
      getHealthReport().then(setHealthReport).catch(() => undefined)
      getProcesses().then((response) => { setProcesses(response.data); setProcessError('') }).catch((reason: Error) => setProcessError(reason.message))
    }
    const interval = window.setInterval(refresh, 15_000)
    return () => window.clearInterval(interval)
  }, [currentUser])

  async function handleLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault()
    setError('')
    setIsSubmitting(true)
    setCredentials(username.trim(), password)

    try {
      const [session, healthResult] = await Promise.all([getSession(), getHealth()])
      setCurrentUser(session.data.username || username.trim())
      setAccessLevel(session.data.accessLevel)
      setHealth(healthResult)
      setPassword('')
      getSystemSummary().then(setSummary).catch(() => setSummary(null))
      getHealthReport().then(setHealthReport).catch(() => setHealthReport(null))
      getProcesses().then((response) => { setProcesses(response.data); setProcessError('') }).catch((reason: Error) => { setProcesses([]); setProcessError(reason.message) })
    } catch (reason) {
      clearCredentials()
      setError(reason instanceof Error && reason.message === 'INVALID_CREDENTIALS'
        ? 'Invalid username or password.'
        : reason instanceof Error ? reason.message : 'Unable to connect to InterSystems IRIS.')
    } finally {
      setIsSubmitting(false)
    }
  }

  function handleLogout() {
    clearCredentials()
    setCurrentUser('')
    setHealth(null)
    setSummary(null)
    setHealthReport(null)
    setProcesses([])
    setProcessError('')
    setUsername('')
    setPassword('')
    setError('')
    setAccessLevel('None')
  }

  if (!currentUser) {
    return (
      <main className="login-page">
        <section className="login-panel">
          <div className="brand login-brand"><img className="brand-mark" src={`${import.meta.env.BASE_URL}logo-mark.png`} alt="MyOwn Portal" /><span>MyOwn Portal</span></div>
          <p className="eyebrow">INTERSYSTEMS IRIS MANAGEMENT</p>
          <h1>Welcome back</h1>
          <p className="login-copy">Sign in with your InterSystems IRIS account to access the management portal.</p>
          <form onSubmit={handleLogin}>
            <label htmlFor="username">Username</label>
            <input id="username" name="username" value={username} onChange={(event) => setUsername(event.target.value)} autoComplete="username" required autoFocus />
            <label htmlFor="password">Password</label>
            <input id="password" name="password" type="password" value={password} onChange={(event) => setPassword(event.target.value)} autoComplete="current-password" required />
            {error && <div className="login-error" role="alert">{error}</div>}
            <button className="login-button" type="submit" disabled={isSubmitting}>{isSubmitting ? 'Signing in…' : 'Sign in'}</button>
          </form>
          <p className="security-note">Your credentials are kept only in this browser tab and are never stored.</p>
        </section>
        <section className="login-visual" aria-hidden="true"><img className="login-logo" src={`${import.meta.env.BASE_URL}logo-large.png`} alt="" /><div className="login-caption"><strong>One portal.</strong><br />Complete control of your IRIS environment.</div></section>
      </main>
    )
  }

  return (
    <div className="shell">
      <aside className="sidebar">
        <div className="brand"><img className="brand-mark" src={`${import.meta.env.BASE_URL}logo-mark.png`} alt="MyOwn Portal" /><span>MyOwn Portal</span></div>
        <nav aria-label="Main navigation">
          {visibleSections.map((item) => (
            <button className={activeSection === item ? 'active' : ''} onClick={() => setActiveSection(item)} key={item} type="button">
              <span aria-hidden="true">{icons[sections.indexOf(item)]}</span>{item}
            </button>
          ))}
        </nav>
        <button className="sidebar-footer account-button" type="button" onClick={handleLogout} title="Sign out"><span className="avatar">{currentUser.slice(0, 2).toUpperCase()}</span><div><strong>{currentUser}</strong><small>{accessLevel} · Sign out</small></div></button>
      </aside>

      <main>
        <header>
          <div><p className="eyebrow">INTERSYSTEMS IRIS</p><h1>{activeSection}</h1></div>
          <div className={`connection ${health ? 'online' : ''}`}><i />{health ? 'Instance online' : error || 'Connecting…'}</div>
        </header>

        {activeSection === 'Overview' && <>
        <section className="hero">
          <div><p className="eyebrow">OPERATIONS CENTER</p><h2>Hello, your environment is<br /><em>ready for you.</em></h2><p>Monitor instance health and access your administrative tools from one place.</p></div>
          <img className="hero-logo" src={`${import.meta.env.BASE_URL}logo-large.png`} alt="" aria-hidden="true" />
        </section>

        <section className="metrics" aria-label="System metrics">
          <article><span className="metric-icon coral">⌁</span><div><small>CPU</small><strong>{summary?.data.cpu.logicalProcessors ?? '—'}</strong><p>Logical processors</p></div></article>
          <article><span className="metric-icon violet">▥</span><div><small>MEMORY</small><strong>{summary ? `${Math.round(summary.data.memory.totalKB / 1024 / 1024)} GB` : '—'}</strong><p>Total physical memory</p></div></article>
          <article><span className="metric-icon mint">◴</span><div><small>DISK</small><strong>{summary && summary.data.disk.usedPercent !== '' ? `${summary.data.disk.usedPercent}%` : '—'}</strong><p>{summary && summary.data.disk.freeGB !== '' ? `${summary.data.disk.freeGB} GB free` : 'Waiting for metrics'}</p></div></article>
          <article><span className="metric-icon blue">◎</span><div><small>PROCESSES</small><strong>{summary?.data.processes ?? '—'}</strong><p>Running IRIS processes</p></div></article>
        </section>

        <section className="details">
          <article>
            <div className="section-title">
              <div><p className="eyebrow">ENVIRONMENT</p><h3>Instance information</h3></div>
              <div className="status-context">
                <span className={`status-pill ${summary?.data.state && summary.data.state > 0 ? 'warning' : ''}`}>● {summary?.data.state === 2 ? 'Alert' : summary?.data.state === 1 ? 'Warning' : 'Operational'}</span>
                {!!summary?.data.state && summary.data.latestAlert?.message && <small><b>Cause:</b> {summary.data.latestAlert.message}</small>}
              </div>
            </div>
            <dl><div><dt>Name</dt><dd>{summary?.data.instance ?? health?.data.instance ?? 'IRIS'}</dd></div><div><dt>Version</dt><dd>{summary?.data.version ?? health?.data.version ?? '2026.2'}</dd></div><div><dt>Uptime</dt><dd>{summary?.data.uptime || '—'}</dd></div><div><dt>Last checked</dt><dd>{summary ? new Date(summary.meta.timestamp).toLocaleTimeString('en-US') : '—'}</dd></div></dl>
          </article>
          <article><div className="section-title"><div><p className="eyebrow">QUICK ACCESS</p><h3>Tools</h3></div></div><div className="quick-grid">{sections.slice(1, 5).filter((item) => visibleSections.includes(item)).map((item) => <button type="button" key={item} onClick={() => setActiveSection(item)}><span>{icons[sections.indexOf(item)]}</span>{item}<b>→</b></button>)}</div></article>
        </section>

        <section className={`health-report ${healthReport ? healthReport.data.status.toLowerCase() : ''}`}>
          <div className="health-score">
            <span>{healthReport?.data.score ?? '—'}</span>
            <small>HEALTH SCORE</small>
          </div>
          <div className="health-analysis">
            <p className="eyebrow">EMBEDDED PYTHON ANALYSIS</p>
            <div className="health-heading"><h3>Instance health</h3><span className="status-pill">● {healthReport?.data.status ?? 'Analyzing'}</span></div>
            <p>{healthReport?.data.summary ?? 'Collecting live IRIS metrics for the health report.'}</p>
          </div>
          <div className="vector-result">
            <p className="eyebrow">IRIS VECTOR SEARCH</p>
            <h4>{healthReport?.data.vectorMatch.title ?? 'Finding the closest health pattern'}</h4>
            <p>{healthReport?.data.vectorMatch.recommendation ?? 'The recommendation will appear when the analysis is ready.'}</p>
            {healthReport && <small>{healthReport.data.vectorMatch.similarity}% pattern similarity</small>}
          </div>
        </section>

        <section className="process-panel">
          <div className="section-title"><div><p className="eyebrow">LIVE ACTIVITY</p><h3>IRIS processes</h3></div><span className="table-count">{processes.length} shown</span></div>
          <div className="table-wrap">
            <table>
              <thead><tr><th>PID</th><th>User</th><th>Namespace</th><th>Routine</th><th>State</th><th>CPU time</th><th>Started (UTC)</th></tr></thead>
              <tbody>
                {processes.map((process) => (
                  <tr key={`${process.pid}-${process.jobNumber}`}>
                    <td className="mono">{process.pid}</td>
                    <td>{process.username || 'System'}</td>
                    <td><span className="namespace-tag">{process.namespace || '—'}</span></td>
                    <td className="routine-cell">{process.routine || '—'}</td>
                    <td><span className="process-state">● {process.state || 'Active'}</span></td>
                    <td className="mono">{process.cpuTime || '0'}</td>
                    <td>{process.startedAt || '—'}</td>
                  </tr>
                ))}
                {!processes.length && <tr><td className="empty-row" colSpan={7}>{processError || 'No process data available.'}</td></tr>}
              </tbody>
            </table>
          </div>
        </section>
        </>}

        {activeSection === 'Permissions' && <PermissionsPage />}
        {activeSection === 'Applications & APIs' && <ApplicationsPage canManage={canManage} />}
        {activeSection === 'Security' && <SecurityPage />}
        {activeSection === 'Tasks' && <TasksPage />}
        {activeSection === 'Logs' && <LogsPage />}
        {!['Overview', 'Permissions', 'Applications & APIs', 'Security', 'Tasks', 'Logs'].includes(activeSection) && <section className="coming-soon"><span>{icons[sections.indexOf(activeSection)]}</span><h2>{activeSection}</h2><p>This module is next in the development roadmap.</p></section>}
      </main>
    </div>
  )
}
