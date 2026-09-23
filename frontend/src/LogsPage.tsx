import { useEffect, useMemo, useState } from 'react'
import { getLogs, type LogItem } from './api/client'

type Period = 'All time' | 'Last 24 hours' | 'Last 7 days'

const pageSize = 20
const messagePreviewLength = 100

function messagePreview(message: string) {
  const normalized = message.replace(/\s+/g, ' ').trim()
  if (normalized.length <= messagePreviewLength) return normalized
  return `${normalized.slice(0, messagePreviewLength).trimEnd()}…`
}

function severityClass(severity: LogItem['severity']) {
  return severity.toLowerCase()
}

// messages.log separates milliseconds with a colon (HH:MM:SS:mmm), which JavaScript
// rejects. The backend already emits HH:MM:SS.mmm; this also accepts the raw form.
function parseTimestamp(timestamp: string) {
  return new Date(timestamp.replace(/(T\d{2}:\d{2}:\d{2}):(\d+)$/, '$1.$2')).getTime()
}

function inPeriod(timestamp: string, period: Period) {
  if (period === 'All time') return true
  const age = Date.now() - parseTimestamp(timestamp)
  const limit = period === 'Last 24 hours' ? 86_400_000 : 7 * 86_400_000
  return Number.isFinite(age) && age <= limit
}

export default function LogsPage() {
  const [logs, setLogs] = useState<LogItem[]>([])
  const [query, setQuery] = useState('')
  const [severity, setSeverity] = useState('All severities')
  const [source, setSource] = useState('All sources')
  const [period, setPeriod] = useState<Period>('All time')
  const [page, setPage] = useState(1)
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selected, setSelected] = useState<LogItem | null>(null)
  const [totalRead, setTotalRead] = useState(0)
  const [limit, setLimit] = useState(500)
  const [truncated, setTruncated] = useState(false)

  const loadLogs = async () => {
    setLoading(true)
    setError('')
    try {
      const response = await getLogs()
      setLogs(response.data.items)
      setTotalRead(response.data.totalRead)
      setLimit(response.data.limit)
      setTruncated(Boolean(response.data.truncated))
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'The system log could not be loaded.')
    } finally {
      setLoading(false)
    }
  }

  useEffect(() => {
    loadLogs()
  }, [])

  const sources = useMemo(() => [...new Set(logs.map((entry) => entry.source))].sort(), [logs])
  const filtered = useMemo(() => logs.filter((entry) => {
    if (severity !== 'All severities' && entry.severity !== severity) return false
    if (source !== 'All sources' && entry.source !== source) return false
    if (!inPeriod(entry.timestamp, period)) return false
    return `${entry.source} ${entry.message} ${entry.pid}`.toLowerCase().includes(query.trim().toLowerCase())
  }), [logs, period, query, severity, source])

  useEffect(() => setPage(1), [period, query, severity, source])

  const pageCount = Math.max(1, Math.ceil(filtered.length / pageSize))
  const visible = filtered.slice((page - 1) * pageSize, page * pageSize)
  const warnings = logs.filter((entry) => entry.severity === 'Warning').length
  const errors = logs.filter((entry) => entry.severity === 'Error' || entry.severity === 'Fatal').length

  return (
    <>
      <section className="page-intro logs-intro">
        <div><p className="eyebrow">SYSTEM EVENTS</p><h2>Unified logs</h2><p>Inspect recent IRIS messages by severity, source, process, and time period.</p></div>
        <div className="permission-stats"><span><strong>{logs.length}</strong>Events</span><span><strong>{warnings}</strong>Warnings</span><span><strong>{errors}</strong>Errors</span></div>
      </section>

      <section className="data-panel">
        <div className="log-panel-heading">
          <p>Read-only and sanitized view of <span className="mono">messages.log</span>.</p>
          <button className="row-action" type="button" disabled={loading} onClick={loadLogs}>{loading ? 'Refreshing…' : 'Refresh'}</button>
        </div>
        <div className="log-filters">
          <label className="search-box"><span>⌕</span><input aria-label="Search logs" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search messages…" /></label>
          <select aria-label="Filter by severity" value={severity} onChange={(event) => setSeverity(event.target.value)}><option>All severities</option><option>Information</option><option>Warning</option><option>Error</option><option>Fatal</option></select>
          <select aria-label="Filter by source" value={source} onChange={(event) => setSource(event.target.value)}><option>All sources</option>{sources.map((name) => <option key={name}>{name}</option>)}</select>
          <select aria-label="Filter by period" value={period} onChange={(event) => setPeriod(event.target.value as Period)}><option>All time</option><option>Last 24 hours</option><option>Last 7 days</option></select>
        </div>
        {loading && <div className="data-state">Loading recent system events…</div>}
        {error && <div className="data-state error-state">{error}</div>}
        {!loading && !error && <div className="table-wrap"><table className="logs-table">
          <thead><tr><th>Timestamp</th><th>Severity</th><th>Source</th><th>PID</th><th>Message</th><th>Actions</th></tr></thead>
          <tbody>{visible.map((entry) => <tr key={entry.id}>
            <td className="mono log-time">{entry.timestamp.replace('T', ' ')}</td>
            <td><span className={`severity-chip ${severityClass(entry.severity)}`}>{entry.severity}</span></td>
            <td><span className="namespace-tag">{entry.source}</span></td>
            <td className="mono">{entry.pid}</td>
            <td className="log-message">{messagePreview(entry.message)}</td>
            <td><button className="row-action" type="button" onClick={() => setSelected(entry)}>View</button></td>
          </tr>)}</tbody>
        </table>{!visible.length && <div className="data-state">No log entries match these filters.</div>}</div>}
        {!loading && !error && <div className="pagination"><span>{filtered.length} matching events</span><div><button type="button" disabled={page === 1} onClick={() => setPage((value) => value - 1)}>Previous</button><b>Page {page} of {pageCount}</b><button type="button" disabled={page === pageCount} onClick={() => setPage((value) => value + 1)}>Next</button></div></div>}
        {!loading && !error && <div className="panel-footnote">{truncated ? `Showing the newest ${limit} of ${totalRead} parsed events.` : `${totalRead} parsed events available.`} Potentially sensitive messages are hidden by the backend.</div>}
      </section>
      {selected && <div className="modal-backdrop" onMouseDown={() => setSelected(null)}>
        <article className="permission-modal log-modal" onMouseDown={(event) => event.stopPropagation()}>
          <button className="modal-close" type="button" aria-label="Close" onClick={() => setSelected(null)}>×</button>
          <p className="eyebrow">LOG EVENT</p>
          <h3>{selected.source || 'IRIS system event'}</h3>
          <div className="detail-grid">
            <span><small>TIMESTAMP</small><b>{selected.timestamp.replace('T', ' ')}</b></span>
            <span><small>SEVERITY</small><b>{selected.severity}</b></span>
            <span><small>PROCESS ID</small><b className="mono">{selected.pid || '—'}</b></span>
            <span><small>SEVERITY CODE</small><b className="mono">{selected.severityCode}</b></span>
          </div>
          <div className="detail-section log-detail-message">
            <div className="detail-heading"><div><small>MESSAGE</small><h4>Event details</h4></div></div>
            <p>{selected.message || 'No message was recorded.'}</p>
          </div>
          <p className="modal-description">This event is read-only. Sensitive content may be replaced before it reaches the browser.</p>
        </article>
      </div>}
    </>
  )
}
