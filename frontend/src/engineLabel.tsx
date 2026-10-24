/** Badge text for the engine that decided: "AI", or "Rules (reason)" when Rules decided instead of the AI. */
export function engineLabel(engine?: string, fallbackReason?: string) {
  if (engine === 'aihub') return 'AI'
  if (engine === 'cooldown') return 'Cooldown'
  return fallbackReason ? `Rules (${fallbackReason})` : 'Rules'
}

/** Shown while MYOWN_AI_MODE=replay: AI answers come from recorded real decisions, not from a live provider. */
export function ReplayBadge() {
  return <span className="status-chip replay-badge" title="MYOWN_AI_MODE=replay: each AI answer is a real model decision recorded earlier (model and date in each fixture); no provider is called.">Replay of recorded real decisions</span>
}
