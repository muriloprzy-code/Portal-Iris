import { useEffect, useMemo, useState } from 'react'
import { getSecurityDetail, getSecurityInventory, getSecuritySummary, type SecurityDetail, type SecurityInventoryError, type SecurityItem, type SecuritySummary } from './api/client'

type Filter = 'All' | 'Certificates' | 'OAuth' | 'Wallet' | 'Credentials'

function categoryMatches(item: SecurityItem, filter: Filter) {
  if (filter === 'All') return true
  if (filter === 'Certificates') return item.category === 'Certificate'
  if (filter === 'Credentials') return item.category === 'Credential'
  return item.category === filter
}

function displayDate(value: string) {
  if (!value) return 'Not applicable'
  const date = new Date(value)
  return Number.isNaN(date.getTime()) ? value : date.toLocaleString('en-US', { dateStyle: 'medium', timeStyle: 'short' })
}

function certificateState(item: SecurityItem) {
  if (item.category !== 'Certificate' || !item.expiresAt) return item.status
  const expires = new Date(item.expiresAt).getTime()
  if (Number.isNaN(expires)) return item.status
  const days = Math.ceil((expires - Date.now()) / 86_400_000)
  if (days < 0) return 'Expired'
  if (days <= 30) return 'Expiring soon'
  return item.status
}

function daysUntilExpiration(item: SecurityItem) {
  if (item.category !== 'Certificate' || !item.expiresAt) return null
  const expires = new Date(item.expiresAt).getTime()
  if (Number.isNaN(expires)) return null
  return Math.ceil((expires - Date.now()) / 86_400_000)
}

export default function SecurityPage() {
  const [items, setItems] = useState<SecurityItem[]>([])
  const [filter, setFilter] = useState<Filter>('All')
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [summary, setSummary] = useState<SecuritySummary | null>(null)
  const [detail, setDetail] = useState<SecurityDetail | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState('')
  const [inventoryErrors, setInventoryErrors] = useState<SecurityInventoryError[]>([])

  useEffect(() => {
    async function loadSecurity() {
      try {
        // Some native security queries use namespace-scoped cursors. Keep the
        // inventory and summary calls sequential to avoid competing cursors.
        const response = await getSecurityInventory()
        const summaryResponse = await getSecuritySummary()
        setItems([
          ...response.data.certificates,
          ...response.data.oauth,
          ...response.data.walletCollections,
          ...response.data.walletSecrets,
          ...response.data.credentials,
        ])
        setSummary(summaryResponse.data)
        setInventoryErrors(response.data.errors ?? [])
      } catch (reason) {
        setError(reason instanceof Error ? reason.message : 'The security inventory could not be loaded.')
      } finally {
        setLoading(false)
      }
    }

    void loadSecurity()
  }, [])

  async function openDetails(item: SecurityItem) {
    setDetail(null)
    setDetailError('')
    setDetailLoading(true)
    try {
      const response = await getSecurityDetail(item)
      setDetail(response.data)
    } catch (reason) {
      setDetailError(reason instanceof Error ? reason.message : 'The security item details could not be loaded.')
    } finally {
      setDetailLoading(false)
    }
  }

  function closeDetails() {
    setDetail(null)
    setDetailError('')
  }

  const visible = useMemo(() => items.filter((item) => {
    if (!categoryMatches(item, filter)) return false
    const text = `${item.name} ${item.category} ${item.type} ${item.issuer} ${item.association}`.toLowerCase()
    return text.includes(query.trim().toLowerCase())
  }), [filter, items, query])

  const certificateCount = items.filter((item) => item.category === 'Certificate').length
  const oauthCount = items.filter((item) => item.category === 'OAuth').length
  const protectedCount = items.filter((item) => item.category === 'Wallet' || item.category === 'Credential').length

  return (
    <>
      <section className="page-intro security-intro">
        <div><p className="eyebrow">SECURITY & SECRETS</p><h2>Security inventory</h2><p>Review certificates, OAuth configurations, wallet metadata, and credential references without exposing secret values.</p></div>
        <div className="permission-stats"><span><strong>{summary?.certificates ?? certificateCount}</strong>Certificates</span><span><strong>{summary?.oauth ?? oauthCount}</strong>OAuth items</span><span><strong>{summary?.protectedItems ?? protectedCount}</strong>Protected items</span></div>
      </section>

      {summary && <section className="security-posture" aria-label="Security access posture"><span><small>NATIVE SECURITY API</small><strong>{Boolean(Number(summary.canReadSecurity)) ? 'Available' : 'Restricted'}</strong></span><span><small>SECURE WALLET ACCESS</small><strong>{Boolean(Number(summary.canUseWallet)) ? 'Available' : 'Restricted'}</strong></span><span><small>PORTAL MODE</small><strong>{summary.mode}</strong></span></section>}

      <section className="data-panel">
        <div className="data-toolbar">
          <div className="tabs security-tabs">{(['All', 'Certificates', 'OAuth', 'Wallet', 'Credentials'] as Filter[]).map((name) => <button className={filter === name ? 'active' : ''} type="button" onClick={() => setFilter(name)} key={name}>{name}</button>)}</div>
          <label className="search-box"><span>⌕</span><input aria-label="Search security inventory" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search security items…" /></label>
        </div>
        {inventoryErrors.length > 0 && <div className="data-state error-state" role="alert"><strong>Some inventories could not be read, so their items are missing from this list.</strong><ul>{inventoryErrors.map((entry) => <li key={entry.category}><b>{entry.category}:</b> {entry.message}</li>)}</ul></div>}
        {loading && <div className="data-state">Loading security inventory…</div>}
        {error && <div className="data-state error-state">{error}</div>}
        {!loading && !error && <div className="table-wrap"><table>
          <thead><tr><th>Name</th><th>Category</th><th>Type</th><th>Status</th><th>Issuer</th><th>Expiration</th><th>Associated configuration</th><th>Actions</th></tr></thead>
          <tbody>{visible.map((item, index) => {
            const state = certificateState(item)
            return <tr key={`${item.category}-${item.name}-${index}`}>
              <td className="primary-cell"><span className="security-name"><i>{item.category.slice(0, 4).toUpperCase()}</i>{item.name || 'Unnamed configuration'}</span></td>
              <td>{item.category}</td>
              <td>{item.type}</td>
              <td><span className={`status-chip ${state === 'Expired' ? 'danger' : state === 'Expiring soon' ? 'suspended' : 'enabled'}`}>{state}</span></td>
              <td className="wrap-cell">{item.issuer || 'Not specified'}</td>
              <td>{displayDate(item.expiresAt)}</td>
              <td className="wrap-cell">{item.association || item.detail || 'Not specified'}</td>
              <td><button className="row-action" type="button" onClick={() => openDetails(item)}>View</button></td>
            </tr>
          })}</tbody>
        </table>{!visible.length && <div className="data-state">No matching security items. No secret values are retrieved by this portal.</div>}</div>}
        {!loading && !error && <div className="panel-footnote secure-footnote">◆ {summary?.mode || 'Read-only metadata view'}. Passwords, tokens, certificate contents, wallet values, and private keys never leave IRIS.</div>}
      </section>

      {(detailLoading || detailError || detail) && <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) closeDetails() }}>
        <section className="permission-modal security-modal" role="dialog" aria-modal="true" aria-label={detail ? `Security item ${detail.name}` : 'Security item details'}>
          <button className="modal-close" type="button" aria-label="Close details" onClick={closeDetails}>×</button>
          {detailLoading && <div className="data-state">Loading secure metadata…</div>}
          {detailError && <div className="data-state error-state">{detailError}</div>}
          {detail && <>
            <p className="eyebrow">{detail.category.toUpperCase()} METADATA</p><h3>{detail.name || 'Unnamed configuration'}</h3>
            <div className="security-safety"><span>◆</span><p><strong>Secret material is protected</strong>{detail.safetyNotice}</p></div>
            <div className="detail-grid security-details">
              <span><small>Category</small><b>{detail.category}</b></span>
              <span><small>Type</small><b>{detail.type}</b></span>
              <span><small>Status</small><b>{certificateState(detail)}</b></span>
              <span><small>Access mode</small><b>{detail.mode}</b></span>
              <span><small>Issuer</small><b>{detail.issuer || 'Not applicable'}</b></span>
              <span><small>Association</small><b>{detail.association || 'Not specified'}</b></span>
              <span><small>Valid from</small><b>{displayDate(detail.validFrom)}</b></span>
              <span><small>Expires</small><b>{displayDate(detail.expiresAt)}</b></span>
            </div>
            {daysUntilExpiration(detail) !== null && <div className={`expiry-banner ${(daysUntilExpiration(detail) ?? 31) <= 30 ? 'warning' : ''}`}><strong>{daysUntilExpiration(detail)! < 0 ? 'Expired' : `${daysUntilExpiration(detail)} days remaining`}</strong><span>Calculated in the browser from the certificate validity metadata.</span></div>}
            <div className="detail-section"><div className="detail-heading"><div><small>SAFE DETAIL</small><h4>Configuration context</h4></div></div><p className="modal-description">{detail.detail || 'No additional non-sensitive metadata is available.'}</p></div>
          </>}
        </section>
      </div>}
    </>
  )
}
