import { useCallback, useEffect, useState } from 'react'
import { analyzeCurrentHealth, getAgentLedgerSummary, getAgentProposals, getAgentStatus, type AgentLedgerSummary, type AgentSimulation, type AgentStatus } from './api/client'
import { engineLabel, ReplayBadge } from './engineLabel'

type AgentOverviewCardProps = {
  canManage: boolean
  onPendingChange: (count: number) => void
  onOpenAgents: () => void
}

const yes = (value: boolean | number | undefined) => Boolean(Number(value))

export default function AgentOverviewCard({ canManage, onPendingChange, onOpenAgents }: AgentOverviewCardProps) {
  const [status, setStatus] = useState<AgentStatus | null>(null)
  const [ledger, setLedger] = useState<AgentLedgerSummary | null>(null)
  const [analysis, setAnalysis] = useState<AgentSimulation | null>(null)
  const [busy, setBusy] = useState(false)
  const [error, setError] = useState('')

  const refresh = useCallback(async () => {
    try {
      const [statusResponse, ledgerResponse] = await Promise.all([getAgentStatus(), getAgentLedgerSummary()])
      setStatus(statusResponse.data)
      setLedger(ledgerResponse.data)
      if (canManage) {
        const proposalsResponse = await getAgentProposals('pending')
        onPendingChange(proposalsResponse.data.length)
      } else {
        onPendingChange(0)
      }
      setError('')
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Agent status is unavailable.')
    }
  }, [canManage, onPendingChange])

  useEffect(() => {
    refresh()
    const interval = window.setInterval(refresh, 15_000)
    return () => window.clearInterval(interval)
  }, [refresh])

  async function analyze() {
    setBusy(true)
    setError('')
    try {
      const response = await analyzeCurrentHealth()
      setAnalysis(response.data)
      await refresh()
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'The health analysis could not be completed.')
    } finally {
      setBusy(false)
    }
  }

  return <section className="agent-overview-card">
    <div className="agent-overview-heading"><div><p className="eyebrow">INTEROPERABILITY AGENT</p><h3>Safe operational decisions</h3><p>Events are analyzed inside the production; every proposed change still requires human confirmation.</p></div><span className={`agent-orb ${status?.activeEngine === 'aihub' ? 'aihub' : ''}`}>✦</span></div>
    <div className="agent-overview-stats"><span><small>ENGINE</small><strong>{status?.activeEngine === 'aihub' ? 'AI Hub' : 'Rules'}</strong>{status?.aiMode === 'replay' && <ReplayBadge />}</span><span><small>DECISIONS</small><strong>{ledger?.decisions ?? '—'}</strong></span><span><small>PRODUCTION</small><strong>{yes(status?.production.running) ? 'Running' : 'Stopped'}</strong></span><span><small>BUDGET</small><strong>{status ? `${status.tokensUsedToday}/${status.dailyTokenBudget}` : '—'}</strong></span></div>
    {analysis && <p className="agent-analysis-result">Latest: <b>{String(analysis.decision?.action || analysis.outcome)}</b> · {engineLabel(analysis.engine, analysis.fallbackReason)} · trace {analysis.traceId}</p>}
    {error && <p className="agent-analysis-error">{error}</p>}
    <div className="agent-overview-actions">{canManage && <button className="state-action" type="button" onClick={analyze} disabled={busy}>{busy ? 'Analyzing…' : 'Analyze current health'}</button>}<button className="row-action" type="button" onClick={onOpenAgents}>Open Agents</button></div>
  </section>
}
