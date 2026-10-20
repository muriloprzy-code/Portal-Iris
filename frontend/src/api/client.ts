export type HealthResponse = {
  data: {
    status: 'ok'
    application: string
    instance: string
    version: string
  }
  meta: { timestamp: string }
}

export type SessionResponse = {
  data: {
    authenticated: boolean
    username: string
    accessLevel: 'Administrator' | 'Viewer' | 'None'
    canView: boolean | number
    canManage: boolean | number
  }
  meta: { timestamp: string }
}

export type SystemSummaryResponse = {
  data: {
    instance: string
    version: string
    namespace: string
    state: number
    alerts: number
    latestAlert: { count: number; message: string }
    seriousAlerts: number
    uptime: string
    databaseSpace: string
    lockTable: string
    processes: number
    cpu: { logicalProcessors: number }
    memory: { totalKB: number }
    disk: { path: string; freeGB: number | ''; totalGB: number | ''; usedPercent: number | '' }
  }
  meta: { timestamp: string }
}

export type HealthReportResponse = {
  data: {
    score: number
    status: 'Healthy' | 'Attention' | 'Critical'
    summary: string
    engine: string
    metrics: {
      diskUsedPercent: number
      databaseSpacePercent: number
      lockTablePercent: number
      seriousAlerts: number
      processes: number
    }
    vectorMatch: {
      code: string
      title: string
      severity: string
      recommendation: string
      similarity: number
    }
    anomalies: Array<{
      metric: string
      label: string
      current: number
      baseline: number
      zScore: number
      severity: 'warning' | 'critical'
    }>
  }
  meta: { timestamp: string }
}

export type ProcessItem = {
  jobNumber: number
  pid: number
  username: string
  namespace: string
  routine: string
  state: string
  clientAddress: string
  cpuTime: number | string
  startedAt: string
}

export type ProcessesResponse = {
  data: ProcessItem[]
  meta: { timestamp: string; limit: number; source: IntegrationSource }
}

export type IntegrationSource = 'sysadmin-v2'
export type IntegrationMeta = { timestamp: string; source: IntegrationSource }

export type SysAdminStatusResponse = {
  data: {
    available: boolean | number
    apiVersion: number
    serverVersion: string
    product: string
    v2Supported: boolean | number
    mode: IntegrationSource
  }
  meta: { timestamp: string }
}

export type PermissionUser = { name: string; enabled: string | number | boolean; roles: string; lastLogin: string }
export type PermissionRole = { name: string; description: string; grantedRoles: string; canBeEdited: boolean }
export type PermissionResource = { name: string; description: string; publicPermission: string; resourceType: string; canBeDeleted: boolean }
export type EffectivePermission = { resource: string; permission: string }
export type PermissionUserDetail = {
  name: string
  fullName: string
  enabled: string | number | boolean
  namespace: string
  comment: string
  expirationDate: string
  lastLogin: string
  loginService: string
  directRoles: string[]
  effectiveRoles: string[]
  effectivePermissions: EffectivePermission[]
}
export type PermissionRoleDetail = {
  name: string
  description: string
  grantedRoles: string[]
  permissions: EffectivePermission[]
  systemRole: boolean
}

export type WebApplication = {
  name: string
  namespace: string
  namespaceDefault: string
  enabled: string | number | boolean
  type: string
  resource: string
  authenticationMethods: string
  systemApplication: boolean
  dispatchClass: string
}

export type WebApplicationDetail = {
  name: string
  description: string
  namespace: string
  enabled: boolean | number
  dispatchClass: string
  resource: string
  authenticationCode: string | number
  cookiePath: string
  sessionUse: string | number
  namespaceDefault: boolean | number
  canManage: boolean
  manageable: boolean
  protectionReason: string
}

export type APITestResult = {
  method: string
  path: string
  status: number
  statusText: string
  durationMs: number
  contentType: string
  body: string
  truncated: boolean | number
}

export type TaskItem = {
  id: number
  name: string
  namespace: string
  taskClass: string
  suspended: string
  lastStarted: string
  lastFinished: string
  lastStatus: string
  lastResult: string
  nextScheduledDate: string
  nextScheduledTime: string
  schedule: string
  interval: string
  manageable: boolean | number
}

export type TaskDetail = TaskItem & {
  description: string
  priority: string
  runAsUser: string
  runningJobNumber: string | number
  protectionReason: string
}

export type TasksResponse = {
  data: { managerStatus: number; tasks: TaskItem[] }
  meta: { timestamp: string; source: IntegrationSource }
}

export type LogItem = {
  id: string
  timestamp: string
  pid: string
  severityCode: number
  severity: 'Information' | 'Warning' | 'Error' | 'Fatal'
  source: string
  message: string
}

export type LogsResponse = {
  data: { items: LogItem[]; totalRead: number; limit: number; truncated: boolean | number; source: string }
  meta: { timestamp: string }
}

export type SecurityItem = {
  name: string
  category: 'Certificate' | 'OAuth' | 'Wallet' | 'Credential'
  type: string
  status: string
  issuer: string
  validFrom: string
  expiresAt: string
  association: string
  detail: string
}

export type SecurityResponse = {
  data: {
    certificates: SecurityItem[]
    oauth: SecurityItem[]
    walletCollections: SecurityItem[]
    walletSecrets: SecurityItem[]
    credentials: SecurityItem[]
    errors?: SecurityInventoryError[]
  }
  meta: IntegrationMeta
}

export type SecurityInventoryError = { category: string; message: string }

export type SecuritySummary = {
  certificates: number
  oauth: number
  walletCollections: number
  walletSecrets: number
  credentials: number
  protectedItems: number
  canReadSecurity: boolean | number
  canUseWallet: boolean | number
  mode: string
}

export type SecurityDetail = SecurityItem & {
  redacted: boolean | number
  mode: string
  safetyNotice: string
}

export type AgentConfig = {
  killSwitch: boolean | number
  readOnly: boolean | number
  enginePreference: 'auto' | 'rules' | 'aihub'
  provider: string
  model: string
  baseURL: string
  autonomyTriage: 'advise' | 'assist' | 'auto-safe'
  autonomyAccess: 'advise' | 'assist' | 'auto-safe'
  dailyTokenBudget: number
  perDecisionTokenBudget: number
  cooldownMinutes: number
  maxAgentCallsPerHour: number
  proposalTTLMinutes: number
  demoMode: boolean | number
  apiKeyConfigured?: boolean | number
}

export type AgentStatus = AgentConfig & {
  aiHubAvailable: boolean | number
  activeEngine: 'rules' | 'aihub'
  tokensUsedToday: number
  production: { name: string; running: boolean | number }
}

export type AgentDecision = {
  id: number
  eventId: number
  workflow: string
  engine: string
  action: string
  severity: string
  riskLevel: string
  targetType: string
  targetId: string
  confidence: number
  validationStatus: string
  downgradedBy: string
  traceId: string
  decidedAt: string
  rationale?: string
  evidence?: unknown[]
  proposalId?: number | string
}

export type AgentProposal = {
  id: number
  decisionId: number
  kind: string
  targetType: string
  targetId: string
  before: unknown
  after: unknown
  requiredPrivilege: string
  undoHint: string
  state: string
  createdAt: string
  expiresAt: string
  resolvedBy: string
  resolvedAt: string
  resultMessage: string
}

export type AgentAccessRequest = {
  id: number
  requester: string
  roleRequested: string
  justification: string
  /** queued while the production is still deciding; then decided, suppressed or failed. */
  status: 'queued' | 'decided' | 'suppressed' | 'failed' | string
  traceId: string
  decisionId: number | string
  proposalId: number | string
  engine: string
  outcome: string
  recommendation?: string
  riskLevel?: string
  createdAt: string
  decidedAt: string
  decision?: AgentDecision
}

export type AgentSimulation = {
  traceId: string
  eventId: number
  decisionId: number
  proposalId: number | string
  engine: string
  outcome: string
  integrationSource?: string
  decision: Record<string, unknown>
  gate?: Record<string, unknown>
}

export type AgentProduction = {
  name: string
  state: number
  running: boolean | number
  items: Array<{ name: string; className: string; enabled: boolean | number }>
}

export type AgentGuardrails = {
  prohibitedTargets: unknown
  stateChangesRequireConfirmation: boolean | number
  agentToolsAreReadOnly: boolean | number
  modelOutputIsUntrusted: boolean | number
  separationOfDuties: boolean | number
  sentToModel: string[]
  neverSentToModel: string[]
}

export type AgentLedgerSummary = {
  decisions: number
  totalTokens: number
  costEstimateUSD: number
  averageDurationMs: number
}

export type AgentTrace = {
  traceId: string
  timeline: Array<Record<string, unknown> & { type: string; at: string }>
}

let authorizationHeader = import.meta.hot?.data.authorizationHeader ?? ''

if (import.meta.hot) {
  import.meta.hot.dispose((data) => {
    data.authorizationHeader = authorizationHeader
  })
}

export function setCredentials(username: string, password: string) {
  const bytes = new TextEncoder().encode(`${username}:${password}`)
  const encoded = btoa(Array.from(bytes, (byte) => String.fromCharCode(byte)).join(''))
  authorizationHeader = `Basic ${encoded}`
}

export function clearCredentials() {
  authorizationHeader = ''
}

async function apiRequest<T>(path: string, signal?: AbortSignal, init: RequestInit = {}): Promise<T> {
  const headers: Record<string, string> = { Accept: 'application/json' }
  if (authorizationHeader) {
    headers.Authorization = authorizationHeader
    // IRIS consumes the standard Authorization header during authentication.
    // Forward the same short-lived value separately for local SysAdmin API calls.
    headers['X-MyOwn-SysAdmin-Authorization'] = authorizationHeader
  }
  if (init.body) headers['Content-Type'] = 'application/json'

  const response = await fetch(`/myown/api${path}`, {
    credentials: 'include',
    ...init,
    headers,
    signal,
  })

  if (!response.ok) {
    if (response.status === 401) {
      window.dispatchEvent(new Event('myown:unauthorized'))
      throw new Error('INVALID_CREDENTIALS')
    }
    const body = await response.json().catch(() => null) as { error?: { message?: string } } | null
    throw new Error(body?.error?.message || `HTTP_${response.status}`)
  }
  return response.json() as Promise<T>
}

export async function getHealth(signal?: AbortSignal): Promise<HealthResponse> {
  return apiRequest<HealthResponse>('/health', signal)
}

export async function getSession(signal?: AbortSignal): Promise<SessionResponse> {
  return apiRequest<SessionResponse>('/session', signal)
}

export async function getSysAdminStatus(signal?: AbortSignal): Promise<SysAdminStatusResponse> {
  return apiRequest<SysAdminStatusResponse>('/sysadmin/status', signal)
}

export async function getSystemSummary(signal?: AbortSignal): Promise<SystemSummaryResponse> {
  return apiRequest<SystemSummaryResponse>('/system/summary', signal)
}

export async function getHealthReport(signal?: AbortSignal): Promise<HealthReportResponse> {
  return apiRequest<HealthReportResponse>('/system/health-report', signal)
}

export async function getProcesses(signal?: AbortSignal): Promise<ProcessesResponse> {
  return apiRequest<ProcessesResponse>('/system/processes', signal)
}

export async function getPermissionUsers() {
  return apiRequest<{ data: PermissionUser[]; meta: IntegrationMeta }>('/permissions/users')
}

export async function getPermissionRoles() {
  return apiRequest<{ data: PermissionRole[]; meta: IntegrationMeta }>('/permissions/roles')
}

export async function getPermissionResources() {
  return apiRequest<{ data: PermissionResource[]; meta: IntegrationMeta }>('/permissions/resources')
}

export async function getPermissionUserDetail(user: string) {
  return apiRequest<{ data: PermissionUserDetail }>(`/permissions/users/${encodeURIComponent(user)}`)
}

export async function getPermissionUserEffective(user: string) {
  return apiRequest<{ data: { user: string; roles: string[]; permissions: EffectivePermission[] } }>(`/permissions/users/${encodeURIComponent(user)}/effective`)
}

export async function getPermissionRoleDetail(role: string) {
  return apiRequest<{ data: PermissionRoleDetail }>(`/permissions/roles/${encodeURIComponent(role)}`)
}

export async function addPermissionUserRole(user: string, role: string) {
  return apiRequest<{ data: { user: string; role: string; action: 'added' } }>(`/permissions/users/${encodeURIComponent(user)}/roles`, undefined, {
    method: 'POST',
    body: JSON.stringify({ role }),
  })
}

export async function removePermissionUserRole(user: string, role: string) {
  return apiRequest<{ data: { user: string; role: string; action: 'removed' } }>(`/permissions/users/${encodeURIComponent(user)}/roles/${encodeURIComponent(role)}`, undefined, {
    method: 'DELETE',
  })
}

export async function getApplications() {
  return apiRequest<{ data: WebApplication[]; meta: IntegrationMeta }>('/applications')
}

export async function getApplicationDetail(name: string) {
  return apiRequest<{ data: WebApplicationDetail }>(`/applications/detail?name=${encodeURIComponent(name)}`)
}

export async function setApplicationEnabled(name: string, enabled: boolean) {
  return apiRequest<{ data: { name: string; enabled: boolean | number; action: 'enabled' | 'disabled' } }>('/applications/state', undefined, {
    method: 'POST',
    body: JSON.stringify({ name, enabled }),
  })
}

export async function testAPI(request: { method: string; path: string; headers: Record<string, string>; body: string; confirmed: boolean }) {
  return apiRequest<{ data: APITestResult }>('/apis/test', undefined, {
    method: 'POST',
    body: JSON.stringify(request),
  })
}

export async function getOpenAPISpec() {
  return apiRequest<Record<string, unknown>>('/openapi')
}

export async function getTasks() {
  return apiRequest<TasksResponse>('/tasks')
}

export async function getTaskDetail(id: number) {
  return apiRequest<{ data: TaskDetail }>(`/tasks/detail?id=${id}`)
}

export async function performTaskAction(id: number, action: 'run' | 'suspend' | 'resume') {
  return apiRequest<{ data: { id: number; action: string; message: string } }>('/tasks/action', undefined, {
    method: 'POST',
    body: JSON.stringify({ id, action }),
  })
}

export async function getLogs() {
  return apiRequest<LogsResponse>('/logs')
}

export async function getSecurityInventory() {
  return apiRequest<SecurityResponse>('/security')
}

export async function getSecuritySummary() {
  return apiRequest<{ data: SecuritySummary }>('/security/summary')
}

export async function getSecurityDetail(item: Pick<SecurityItem, 'category' | 'name' | 'type'>) {
  const query = new URLSearchParams({ category: item.category, name: item.name, type: item.type })
  return apiRequest<{ data: SecurityDetail }>(`/security/detail?${query}`)
}

export async function getAgentStatus() {
  return apiRequest<{ data: AgentStatus }>('/agent/status')
}

export async function getAgentConfig() {
  return apiRequest<{ data: AgentConfig }>('/agent/config')
}

export async function updateAgentConfig(config: Partial<AgentConfig>) {
  return apiRequest<{ data: AgentConfig }>('/agent/config', undefined, { method: 'PUT', body: JSON.stringify(config) })
}

export async function setAgentKillSwitch(enabled: boolean) {
  return apiRequest<{ data: AgentConfig }>('/agent/killswitch', undefined, { method: 'POST', body: JSON.stringify({ enabled }) })
}

export async function getAgentDecisions() {
  return apiRequest<{ data: AgentDecision[] }>('/agent/decisions')
}

export async function getAgentDecision(id: number) {
  return apiRequest<{ data: AgentDecision }>(`/agent/decisions/${id}`)
}

export async function getAgentProposals(state = '') {
  const query = state ? `?state=${encodeURIComponent(state)}` : ''
  return apiRequest<{ data: AgentProposal[] }>(`/agent/proposals${query}`)
}

export async function confirmAgentProposal(id: number) {
  return apiRequest<{ data: AgentProposal }>(`/agent/proposals/${id}/confirm`, undefined, { method: 'POST' })
}

export async function rejectAgentProposal(id: number, reason: string) {
  return apiRequest<{ data: AgentProposal }>(`/agent/proposals/${id}/reject`, undefined, { method: 'POST', body: JSON.stringify({ reason }) })
}

export async function submitAgentAccessRequest(role: string, justification: string) {
  return apiRequest<{ data: AgentAccessRequest }>('/agent/access-requests', undefined, { method: 'POST', body: JSON.stringify({ role, justification }) })
}

export async function getAgentAccessRequests() {
  return apiRequest<{ data: AgentAccessRequest[] }>('/agent/access-requests')
}

export async function getAgentLedgerSummary() {
  return apiRequest<{ data: AgentLedgerSummary }>('/agent/ledger/summary')
}

export async function getAgentTrace(traceId: string) {
  return apiRequest<{ data: AgentTrace }>(`/agent/traces/${encodeURIComponent(traceId)}`)
}

export async function getAgentProduction() {
  return apiRequest<{ data: AgentProduction }>('/agent/production/status')
}

export async function controlAgentProduction(action: 'start' | 'stop') {
  return apiRequest<{ data: AgentProduction }>(`/agent/production/${action}`, undefined, { method: 'POST' })
}

export async function getAgentGuardrails() {
  return apiRequest<{ data: AgentGuardrails }>('/agent/guardrails')
}

export async function simulateAgentScenario(scenario: string, taskId = 0) {
  return apiRequest<{ data: AgentSimulation }>('/agent/simulate', undefined, { method: 'POST', body: JSON.stringify({ scenario, taskId }) })
}

export async function analyzeCurrentHealth() {
  return apiRequest<{ data: AgentSimulation }>('/agent/analyze', undefined, { method: 'POST' })
}
