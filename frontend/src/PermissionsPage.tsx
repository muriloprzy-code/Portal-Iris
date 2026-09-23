import { useCallback, useEffect, useMemo, useState } from 'react'
import {
  addPermissionUserRole,
  getPermissionResources,
  getPermissionRoleDetail,
  getPermissionRoles,
  getPermissionUserDetail,
  getPermissionUsers,
  removePermissionUserRole,
  type EffectivePermission,
  type PermissionResource,
  type PermissionRole,
  type PermissionRoleDetail,
  type PermissionUser,
  type PermissionUserDetail,
} from './api/client'

type Tab = 'Users' | 'Roles' | 'Resources'

function isEnabled(value: string) {
  const normalized = String(value).normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
  return String(value) === '1' || normalized === 'true' || normalized === 'sim' || normalized.includes('yes') || normalized.includes('enabled') || normalized.includes('ativado') || normalized.includes('habilitado') || normalized === 'ativo'
}

function displayPermission(value: string) {
  if (!value) return 'None'
  const labels: Record<string, string> = { R: 'Read', W: 'Write', U: 'Use' }
  return value.split('').map((letter) => labels[letter] || letter).join(', ')
}

function displayResourceType(value: string) {
  return value.replace(/Sistema/gi, 'System').replace(/Usu.rio/gi, 'User')
}

function roleDescription(role: PermissionRole) {
  return role.name.startsWith('%') ? 'Built-in IRIS role.' : (role.description || 'Custom IRIS role.')
}

function resourceDescription(resource: PermissionResource) {
  const type = displayResourceType(resource.resourceType).toLowerCase()
  return type.includes('system') ? 'Built-in IRIS access control resource.' : 'Application access control resource.'
}

function PermissionList({ items, empty }: { items: EffectivePermission[]; empty: string }) {
  if (!items.length) return <p className="detail-empty">{empty}</p>
  return <div className="permission-list">{items.map((item) => <div key={`${item.resource}-${item.permission}`}><span>{item.resource}</span><b>{displayPermission(item.permission)}</b></div>)}</div>
}

export default function PermissionsPage() {
  const [tab, setTab] = useState<Tab>('Users')
  const [query, setQuery] = useState('')
  const [users, setUsers] = useState<PermissionUser[]>([])
  const [roles, setRoles] = useState<PermissionRole[]>([])
  const [resources, setResources] = useState<PermissionResource[]>([])
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [userDetail, setUserDetail] = useState<PermissionUserDetail | null>(null)
  const [roleDetail, setRoleDetail] = useState<PermissionRoleDetail | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [detailError, setDetailError] = useState('')
  const [roleToAdd, setRoleToAdd] = useState('')
  const [actionBusy, setActionBusy] = useState(false)
  const [actionMessage, setActionMessage] = useState('')

  const loadInventory = useCallback(async () => {
    const [userResponse, roleResponse, resourceResponse] = await Promise.all([getPermissionUsers(), getPermissionRoles(), getPermissionResources()])
    setUsers(userResponse.data)
    setRoles(roleResponse.data)
    setResources(resourceResponse.data)
  }, [])

  useEffect(() => {
    loadInventory()
      .catch(() => setError('Security data could not be loaded. Check the IRIS permissions assigned to this user.'))
      .finally(() => setLoading(false))
  }, [loadInventory])

  const rows = useMemo(() => {
    const source = tab === 'Users' ? users : tab === 'Roles' ? roles : resources
    const normalized = query.trim().toLowerCase()
    return normalized ? source.filter((item) => `${item.name} ${'description' in item ? item.description : ''}`.toLowerCase().includes(normalized)) : source
  }, [query, resources, roles, tab, users])

  const availableRoles = useMemo(() => roles.filter((role) => role.name !== '%All' && !userDetail?.directRoles.includes(role.name)), [roles, userDetail])

  async function openUser(name: string) {
    setUserDetail(null)
    setRoleDetail(null)
    setDetailError('')
    setActionMessage('')
    setRoleToAdd('')
    setDetailLoading(true)
    try {
      const response = await getPermissionUserDetail(name)
      setUserDetail(response.data)
    } catch (requestError) {
      setDetailError(requestError instanceof Error ? requestError.message : 'The user details could not be loaded.')
    } finally {
      setDetailLoading(false)
    }
  }

  async function openRole(name: string) {
    setUserDetail(null)
    setRoleDetail(null)
    setDetailError('')
    setActionMessage('')
    setDetailLoading(true)
    try {
      const response = await getPermissionRoleDetail(name)
      setRoleDetail(response.data)
    } catch (requestError) {
      setDetailError(requestError instanceof Error ? requestError.message : 'The role details could not be loaded.')
    } finally {
      setDetailLoading(false)
    }
  }

  function closeDetails() {
    setUserDetail(null)
    setRoleDetail(null)
    setDetailError('')
    setDetailLoading(false)
  }

  async function refreshUser(name: string) {
    const [detailResponse, usersResponse] = await Promise.all([getPermissionUserDetail(name), getPermissionUsers()])
    setUserDetail(detailResponse.data)
    setUsers(usersResponse.data)
  }

  async function addRole() {
    if (!userDetail || !roleToAdd) return
    if (!window.confirm(`Assign the ${roleToAdd} role to ${userDetail.name}?`)) return
    const selectedRole = roleToAdd
    setActionBusy(true)
    setActionMessage('')
    try {
      await addPermissionUserRole(userDetail.name, selectedRole)
      await refreshUser(userDetail.name)
      setRoleToAdd('')
      setActionMessage(`The ${selectedRole} role was assigned successfully.`)
    } catch (requestError) {
      setActionMessage(requestError instanceof Error ? requestError.message : 'The role could not be assigned.')
    } finally {
      setActionBusy(false)
    }
  }

  async function removeRole(role: string) {
    if (!userDetail) return
    if (!window.confirm(`Remove the ${role} role from ${userDetail.name}?`)) return
    setActionBusy(true)
    setActionMessage('')
    try {
      await removePermissionUserRole(userDetail.name, role)
      await refreshUser(userDetail.name)
      setActionMessage(`The ${role} role was removed successfully.`)
    } catch (requestError) {
      setActionMessage(requestError instanceof Error ? requestError.message : 'The role could not be removed.')
    } finally {
      setActionBusy(false)
    }
  }

  return (
    <>
      <section className="page-intro">
        <div><p className="eyebrow">ACCESS CONTROL</p><h2>Permissions management</h2><p>Review users, inspect effective permissions, and manage role assignments.</p></div>
        <div className="permission-stats"><span><strong>{users.length}</strong>Users</span><span><strong>{roles.length}</strong>Roles</span><span><strong>{resources.length}</strong>Resources</span></div>
      </section>

      <section className="data-panel">
        <div className="data-toolbar">
          <div className="tabs">{(['Users', 'Roles', 'Resources'] as Tab[]).map((name) => <button className={tab === name ? 'active' : ''} type="button" onClick={() => setTab(name)} key={name}>{name}</button>)}</div>
          <label className="search-box"><span>⌕</span><input aria-label={`Search ${tab.toLowerCase()}`} value={query} onChange={(event) => setQuery(event.target.value)} placeholder={`Search ${tab.toLowerCase()}…`} /></label>
        </div>

        {loading && <div className="data-state">Loading security inventory…</div>}
        {error && <div className="data-state error-state">{error}</div>}
        {!loading && !error && <div className="table-wrap"><table>
          {tab === 'Users' && <><thead><tr><th>User</th><th>Status</th><th>Roles</th><th>Last login</th><th>Actions</th></tr></thead><tbody>{(rows as PermissionUser[]).map((user) => <tr key={user.name}><td className="primary-cell">{user.name}</td><td><span className={`status-chip ${isEnabled(user.enabled) ? 'enabled' : ''}`}>{isEnabled(user.enabled) ? 'Enabled' : 'Disabled'}</span></td><td className="wrap-cell">{user.roles || 'No roles'}</td><td>{user.lastLogin || 'Never'}</td><td><button className="row-action" type="button" onClick={() => openUser(user.name)}>Manage</button></td></tr>)}</tbody></>}
          {tab === 'Roles' && <><thead><tr><th>Role</th><th>Description</th><th>Granted roles</th><th>Editable</th><th>Actions</th></tr></thead><tbody>{(rows as PermissionRole[]).map((role) => <tr key={role.name}><td className="primary-cell">{role.name}</td><td className="wrap-cell">{roleDescription(role)}</td><td className="wrap-cell">{role.grantedRoles || 'None'}</td><td>{role.canBeEdited ? 'Yes' : 'System role'}</td><td><button className="row-action" type="button" onClick={() => openRole(role.name)}>View</button></td></tr>)}</tbody></>}
          {tab === 'Resources' && <><thead><tr><th>Resource</th><th>Type</th><th>Public permission</th><th>Description</th></tr></thead><tbody>{(rows as PermissionResource[]).map((resource) => <tr key={resource.name}><td className="primary-cell">{resource.name}</td><td>{displayResourceType(resource.resourceType) || '—'}</td><td>{displayPermission(resource.publicPermission)}</td><td className="wrap-cell">{resourceDescription(resource)}</td></tr>)}</tbody></>}
        </table>{!rows.length && <div className="data-state">No matching {tab.toLowerCase()}.</div>}</div>}
      </section>

      {(detailLoading || detailError || userDetail || roleDetail) && <div className="modal-backdrop" role="presentation" onMouseDown={(event) => { if (event.target === event.currentTarget) closeDetails() }}>
        <section className="permission-modal" role="dialog" aria-modal="true" aria-label={userDetail ? `Manage ${userDetail.name}` : roleDetail ? `View ${roleDetail.name}` : 'Permission details'}>
          <button className="modal-close" type="button" aria-label="Close details" onClick={closeDetails}>×</button>
          {detailLoading && <div className="data-state">Loading permission details…</div>}
          {detailError && <div className="data-state error-state">{detailError}</div>}

          {userDetail && <>
            <p className="eyebrow">USER DETAILS</p><h3>{userDetail.name}</h3>
            <div className="detail-grid"><span><small>Status</small><b>{isEnabled(userDetail.enabled) ? 'Enabled' : 'Disabled'}</b></span><span><small>Default namespace</small><b>{userDetail.namespace || 'Not set'}</b></span><span><small>Full name</small><b>{userDetail.fullName || 'Not set'}</b></span><span><small>Last login</small><b>{userDetail.lastLogin || 'Never'}</b></span></div>
            <div className="detail-section"><div className="detail-heading"><div><small>DIRECT ASSIGNMENTS</small><h4>Assigned roles</h4></div><span>{userDetail.directRoles.length}</span></div>
              <div className="role-chips">{userDetail.directRoles.length ? userDetail.directRoles.map((role) => <span key={role}>{role}{role !== '%All' && <button type="button" disabled={actionBusy} aria-label={`Remove ${role}`} onClick={() => removeRole(role)}>×</button>}</span>) : <p className="detail-empty">No roles are directly assigned.</p>}</div>
              <div className="role-assignment"><select aria-label="Role to assign" value={roleToAdd} onChange={(event) => setRoleToAdd(event.target.value)}><option value="">Select a role…</option>{availableRoles.map((role) => <option value={role.name} key={role.name}>{role.name}</option>)}</select><button type="button" disabled={!roleToAdd || actionBusy} onClick={addRole}>{actionBusy ? 'Saving…' : 'Assign role'}</button></div>
              {actionMessage && <p className="action-message">{actionMessage}</p>}
            </div>
            <div className="detail-section"><div className="detail-heading"><div><small>INHERITED ACCESS</small><h4>Effective roles</h4></div><span>{userDetail.effectiveRoles.length}</span></div><div className="role-chips readonly">{userDetail.effectiveRoles.map((role) => <span key={role}>{role}</span>)}</div></div>
            <div className="detail-section"><div className="detail-heading"><div><small>CALCULATED BY IRIS</small><h4>Effective permissions</h4></div><span>{userDetail.effectivePermissions.length}</span></div><PermissionList items={userDetail.effectivePermissions} empty="No effective permissions were returned." /></div>
          </>}

          {roleDetail && <>
            <p className="eyebrow">ROLE DETAILS</p><h3>{roleDetail.name}</h3>
            <p className="modal-description">{roleDetail.systemRole ? 'Built-in IRIS role.' : (roleDetail.description || 'Custom IRIS role.')}</p>
            <div className="detail-section"><div className="detail-heading"><div><small>INHERITANCE</small><h4>Granted roles</h4></div><span>{roleDetail.grantedRoles.length}</span></div><div className="role-chips readonly">{roleDetail.grantedRoles.length ? roleDetail.grantedRoles.map((role) => <span key={role}>{role}</span>) : <p className="detail-empty">This role does not grant other roles.</p>}</div></div>
            <div className="detail-section"><div className="detail-heading"><div><small>ACCESS</small><h4>Resource permissions</h4></div><span>{roleDetail.permissions.length}</span></div><PermissionList items={roleDetail.permissions} empty="No resource permissions are assigned." /></div>
          </>}
        </section>
      </div>}
    </>
  )
}
