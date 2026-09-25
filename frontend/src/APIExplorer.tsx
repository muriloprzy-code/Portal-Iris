import { useState } from 'react'
import { getOpenAPISpec, testAPI, type APITestResult } from './api/client'

type ExplorerView = 'Request' | 'OpenAPI'

const presets = [
  { label: 'Health', path: '/myown/api/health' },
  { label: 'System summary', path: '/myown/api/system/summary' },
  { label: 'Applications', path: '/myown/api/applications' },
  { label: 'OpenAPI', path: '/myown/api/openapi' },
]

function parseHeaders(source: string) {
  const result: Record<string, string> = {}
  for (const line of source.split('\n').map((value) => value.trim()).filter(Boolean)) {
    const separator = line.indexOf(':')
    if (separator < 1) throw new Error(`Invalid header: ${line}`)
    result[line.slice(0, separator).trim()] = line.slice(separator + 1).trim()
  }
  return result
}

function prettyBody(value: string) {
  try { return JSON.stringify(JSON.parse(value), null, 2) } catch { return value }
}

export default function APIExplorer() {
  const [view, setView] = useState<ExplorerView>('Request')
  const [method, setMethod] = useState('GET')
  const [path, setPath] = useState('/myown/api/health')
  const [headers, setHeaders] = useState('Accept: application/json')
  const [body, setBody] = useState('')
  const [result, setResult] = useState<APITestResult | null>(null)
  const [spec, setSpec] = useState<Record<string, unknown> | null>(null)
  const [loading, setLoading] = useState(false)
  const [error, setError] = useState('')

  async function runRequest() {
    setError('')
    setResult(null)
    const changesState = !['GET', 'HEAD'].includes(method)
    if (changesState && !window.confirm(`${method} can change server state. Execute this local request?`)) return
    try {
      const parsedHeaders = parseHeaders(headers)
      setLoading(true)
      const response = await testAPI({ method, path: path.trim(), headers: parsedHeaders, body, confirmed: changesState })
      setResult(response.data)
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'The request could not be completed.')
    } finally {
      setLoading(false)
    }
  }

  async function showOpenAPI() {
    setView('OpenAPI')
    setError('')
    if (spec) return
    setLoading(true)
    try {
      const response = await getOpenAPISpec()
      setSpec(response)
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'The OpenAPI specification could not be loaded.')
    } finally {
      setLoading(false)
    }
  }

  return <section className="api-explorer">
    <div className="explorer-heading">
      <div><p className="eyebrow">LOCAL API WORKBENCH</p><h3>REST API Explorer</h3><p>Test approved endpoints on this IRIS instance without allowing external destinations.</p></div>
      <div className="tabs"><button className={view === 'Request' ? 'active' : ''} type="button" onClick={() => setView('Request')}>Request</button><button className={view === 'OpenAPI' ? 'active' : ''} type="button" onClick={showOpenAPI}>OpenAPI</button></div>
    </div>

    {view === 'Request' && <>
      <div className="preset-row"><small>EXAMPLES</small>{presets.map((preset) => <button type="button" key={preset.path} onClick={() => { setMethod('GET'); setPath(preset.path); setBody(''); setResult(null) }}>{preset.label}</button>)}</div>
      <div className="request-line"><select aria-label="HTTP method" value={method} onChange={(event) => setMethod(event.target.value)}>{['GET', 'HEAD', 'POST', 'PUT', 'PATCH', 'DELETE'].map((value) => <option key={value}>{value}</option>)}</select><input aria-label="Request path" value={path} onChange={(event) => setPath(event.target.value)} placeholder="/myown/api/health" /><button type="button" disabled={loading || !path.trim()} onClick={runRequest}>{loading ? 'Sending…' : 'Send request'}</button></div>
      <div className="request-editors"><label><span>HEADERS</span><textarea aria-label="Request headers" value={headers} onChange={(event) => setHeaders(event.target.value)} spellCheck={false} /></label><label><span>BODY</span><textarea aria-label="Request body" value={body} onChange={(event) => setBody(event.target.value)} placeholder="Optional JSON body" spellCheck={false} /></label></div>
      <p className="explorer-guard">Only local paths beginning with <code>/myown/api/</code> or <code>/api/</code> are accepted. Redirects and credential headers are blocked.</p>
      {error && <div className="explorer-error">{error}</div>}
      {result && <div className="response-panel"><div className="response-summary"><span className={`response-code ${result.status >= 200 && result.status < 300 ? 'success' : 'failure'}`}>{result.status} {result.statusText}</span><span>{result.durationMs} ms</span><span>{result.contentType || 'Unknown content type'}</span></div>{Boolean(Number(result.truncated)) && <p className="truncate-note">Response truncated at 64 KB.</p>}<pre>{prettyBody(result.body) || '(empty response body)'}</pre></div>}
    </>}

    {view === 'OpenAPI' && <div className="openapi-panel">{loading && <div className="data-state">Loading OpenAPI specification…</div>}{error && <div className="explorer-error">{error}</div>}{spec && <pre>{JSON.stringify(spec, null, 2)}</pre>}</div>}
  </section>
}
