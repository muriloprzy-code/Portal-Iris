/** Badge text for the engine that decided: "AI", or "Rules (reason)" when Rules decided instead of the AI. */
export function engineLabel(engine?: string, fallbackReason?: string) {
  if (engine === 'aihub') return 'AI'
  if (engine === 'cooldown') return 'Cooldown'
  return fallbackReason ? `Rules (${fallbackReason})` : 'Rules'
}
