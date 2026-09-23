import { useEffect, useMemo, useState } from 'react'
import { getApplicationDetail, getApplications, setApplicationEnabled, type WebApplication, type WebApplicationDetail } from './api/client'
import APIExplorer from './APIExplorer'

type Filter = 'All' | 'REST' | 'Enabled'
type PageView = 'Inventory' | 'API Explorer'

function isEnabled(value: string) {
  const normalized = value.normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  return value === '1' || normalized === 'true' || normalized === 'sim' || normalized.includes('yes') || normalized.includes('enabled') || normalized.includes('ativado') || normalized.includes('habilitado') || normalized === 'ativo'
}

function isRest(application: WebApplication) {
  return application.type.toLowerCase().includes('rest') || application.dispatchClass.toLowerCase().includes('rest')
}

function displayType(value: string) {
  return value.replace(/Sistema/gi, 'System')
}

function displayAuthentication(value: string) {
  return value
    .split(',')
    .map((method) => {
      const normalized = method.normalize('NFD').replace(/[\u0300-\u036f]/g, '').trim().toLowerCase()
      if (normalized === 'senha') return 'Password'
      if (normalized.includes('autenticado')) return 'Unauthenticated'
      return method.trim()
    })
    .filter(Boolean)
    .join(', ') || 'Not specified'
}

export default function ApplicationsPage({ canManage }: { canManage: boolean }) {
  const [applications, setApplications] = useState<WebApplication[]>([])
  const [filter, setFilter] = useState<Filter>('All')
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [detail, setDetail] = useState<WebApplicationDetail | null>(null)
  const [selectedApplication, setSelectedApplication] = useState<WebApplication | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState('')
  const [actionBusy, setActionBusy] = useState(false)
  const [actionMessage, setActionMessage] = useState('')
  const [pageView, setPageView] = useState<PageView>('Inventory')

  async function loadApplications() {
    const response = await getApplications()
    setApplications(response.data)
    return response.data
  }

  useEffect(() => { loadApplications().catch((reason: Error) => setError(reason.message || 'The web application inventory could not be loaded.')).finally(() => setLoading(false)) }, [])

  async function openDetails(application: WebApplication) {
    setSelectedApplication(application)
    setDetail(null)
    setDetailError('')
    setActionMessage('')
    setDetailLoading(true)
    try {
      const response = await getApplicationDetail(application.name)
      setDetail(response.data)
    } catch (reason) {
      setDetailError(reason instanceof Error ? reason.message : 'The application details could not be loaded.')
    } finally {
      setDetailLoading(false)
    }
  }

  function closeDetails() {
    if (actionBusy) return
    setDetail(null)
    setSelectedApplication(null)
    setDetailError('')
    setActionMessage('')
  }

  async function changeState() {
    if (!detail || !selectedApplication || actionBusy) return
    const currentlyEnabled = Boolean(Number(detail.enabled))
    const nextEnabled = !currentlyEnabled
    const verb = nextEnabled ? 'enable' : 'disable'
    if (!window.confirm(`Are you sure you want to ${verb} ${detail.name}?`)) return

    setActionBusy(true)
    setActionMessage('')
    try {
      await setApplicationEnabled(detail.name, nextEnabled)
      const [updatedApplications, updatedDetail] = await Promise.all([loadApplications(), getApplicationDetail(detail.name)])
      setSelectedApplication(updatedApplications.find((application) => application.name === detail.name) || selectedApplication)
      setDetail(updatedDetail.data)
      setActionMessage(`${detail.name} was ${nextEnabled ? 'enabled' : 'disabled'} successfully.`)
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : 'The application state could not be changed.')
    } finally {
      setActionBusy(false)
    }
  }

  const visible = useMemo(() => applications.filter((application) => {
    if (filter === 'REST' && !isRest(application)) return false
    if (filter === 'Enabled' && !isEnabled(application.enabled)) return false
    const text = `${application.name} ${application.namespace} ${application.dispatchClass}`.toLowerCase()
    return text.includes(query.trim().toLowerCase())
  }), [applications, filter, query])

  const restCount = applications.filter(isRest).length
  const enabledCount = applications.filter((application) => isEnabled(application.enabled)).length

  return (
    <>
      <section className="page-intro applications-intro">
        <div><p className="eyebrow">WEB GATEWAY</p><h2>Applications & APIs</h2><p>Inspect web applications, REST dispatch classes, namespaces, and authentication settings.</p></div>
        <div className="permission-stats"><span><strong>{applications.length}</strong>Applications</span><span><strong>{restCount}</strong>REST APIs</span><span><strong>{enabledCount}</strong>Enabled</span></div>
      </section>

      <div className="module-switch" role="group" aria-label="Applications module view"><button className={pageView === 'Inventory' ? 'active' : ''} type="button" onClick={() => setPageView('Inventory')}>Application inventory</button>{canManage && <button className={pageView === 'API Explorer' ? 'active' : ''} type="button" onClick={() => setPageView('API Explorer')}>REST API Explorer</button>}</div>

      {pageView === 'Inventory' && <section className="data-panel">
        <div className="data-toolbar">
          <div className="tabs">{(['All', 'REST', 'Enabled'] as Filter[]).map((name) => <button className={filter === name ? 'active' : ''} type="button" onClick={() => setFilter(name)} key={name}>{name}</button>)}</div>
          <label className="search-box"><span>⌕</span><input aria-label="Search applications" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search applications…" /></label>
        </div>
        {loading && <div className="data-state">Loading web applications…</div>}
        {error && <div className="data-state error-state">{error}</div>}
        {!loading && !error && <div className="table-wrap"><table>
          <thead><tr><th>Application</th><th>Status</th><th>Namespace</th><th>Type</th><th>Dispatch class</th><th>Authentication</th><th>Actions</th></tr></thead>
          <tbody>{visible.map((application) => <tr key={application.name}>
            <td className="primary-cell"><span className="app-name"><i className={isRest(application) ? 'rest' : ''}>{isRest(application) ? 'API' : 'WEB'}</i>{application.name}</span></td>
            <td><span className={`status-chip ${isEnabled(application.enabled) ? 'enabled' : ''}`}>{isEnabled(application.enabled) ? 'Enabled' : 'Disabled'}</span></td>
            <td><span className="namespace-tag">{application.namespace || '—'}</span></td>
            <td>{displayType(application.type) || (isRest(application) ? 'REST' : 'Web')}</td>
            <td className="mono routine-cell">{application.dispatchClass || '—'}</td>
            <td className="wrap-cell">{displayAuthentication(application.authenticationMethods)}</td>
            <td><button className="row-action" type="button" onClick={() => openDetails(application)}>View</button></td>
          </tr>)}</tbody>
        </table>{!visible.length && <div className="data-state">No matching applications.</div>}</div>}
      </section>}

      {pageView === 'API Explorer' && canManage && <APIExplorer />}

      {(detailLoading || detailError || selectedApplication) && <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) closeDetails() }}>
        <section className="permission-modal application-modal" role="dialog" aria-modal="true" aria-label={selectedApplication ? `Application ${selectedApplication.name}` : 'Application details'}>
          <button className="modal-close" type="button" aria-label="Close details" onClick={closeDetails}>×</button>
          {detailLoading && <div className="data-state">Loading application details…</div>}
          {detailError && <div className="data-state error-state">{detailError}</div>}
          {detail && selectedApplication && <>
            <p className="eyebrow">WEB APPLICATION</p><h3>{detail.name}</h3>
            <p className="modal-description">{detail.description || 'No description is configured for this application.'}</p>
            <div className="detail-grid application-details">
              <span><small>Status</small><b>{Boolean(Number(detail.enabled)) ? 'Enabled' : 'Disabled'}</b></span>
              <span><small>Namespace</small><b>{detail.namespace || 'Not set'}</b></span>
              <span><small>Type</small><b>{displayType(selectedApplication.type) || (isRest(selectedApplication) ? 'REST' : 'Web')}</b></span>
              <span><small>Namespace default</small><b>{Boolean(Number(detail.namespaceDefault)) ? 'Yes' : 'No'}</b></span>
              <span><small>Dispatch class</small><b className="mono">{detail.dispatchClass || 'Not set'}</b></span>
              <span><small>Resource</small><b className="mono">{detail.resource || 'Not set'}</b></span>
              <span><small>Authentication</small><b>{displayAuthentication(selectedApplication.authenticationMethods)}</b></span>
              <span><small>Cookie path</small><b>{detail.cookiePath || 'Not set'}</b></span>
            </div>
            <div className="detail-section application-control">
              <div><small>AVAILABILITY CONTROL</small><h4>{detail.manageable ? 'Project application' : 'Protected application'}</h4></div>
              {!Boolean(Number(detail.manageable)) && <p className="protection-note">{detail.protectionReason}</p>}
              {Boolean(Number(detail.manageable)) && !Boolean(Number(detail.canManage)) && <p className="protection-note">Your IRIS account does not have permission to change this application.</p>}
              {Boolean(Number(detail.manageable)) && Boolean(Number(detail.canManage)) && <button className={`state-action ${Boolean(Number(detail.enabled)) ? 'danger' : ''}`} type="button" disabled={actionBusy} onClick={changeState}>{actionBusy ? 'Saving…' : Boolean(Number(detail.enabled)) ? 'Disable application' : 'Enable application'}</button>}
              {actionMessage && <p className="action-message">{actionMessage}</p>}
            </div>
          </>}
        </section>
      </div>}
    </>
  )
}
