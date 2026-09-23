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
  meta: { timestamp: string; limit: number }
}

export type PermissionUser = { name: string; enabled: string; roles: string; lastLogin: string }
export type PermissionRole = { name: string; description: string; grantedRoles: string; canBeEdited: boolean }
export type PermissionResource = { name: string; description: string; publicPermission: string; resourceType: string; canBeDeleted: boolean }
export type EffectivePermission = { resource: string; permission: string }
export type PermissionUserDetail = {
  name: string
  fullName: string
  enabled: string
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
  enabled: string
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
  meta: { timestamp: string }
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
  meta: { timestamp: string }
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
  if (authorizationHeader) headers.Authorization = authorizationHeader
  if (init.body) headers['Content-Type'] = 'application/json'

  const response = await fetch(`/meuportal/api${path}`, {
    credentials: 'include',
    ...init,
    headers,
    signal,
  })

  if (!response.ok) {
    if (response.status === 401) {
      window.dispatchEvent(new Event('meuportal:unauthorized'))
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
  return apiRequest<{ data: PermissionUser[] }>('/permissions/users')
}

export async function getPermissionRoles() {
  return apiRequest<{ data: PermissionRole[] }>('/permissions/roles')
}

export async function getPermissionResources() {
  return apiRequest<{ data: PermissionResource[] }>('/permissions/resources')
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
  return apiRequest<{ data: WebApplication[] }>('/applications')
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
