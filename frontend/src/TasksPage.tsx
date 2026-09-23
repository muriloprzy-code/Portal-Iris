import { useEffect, useMemo, useState } from 'react'
import { getTaskDetail, getTasks, performTaskAction, type TaskDetail, type TaskItem } from './api/client'

type Filter = 'All' | 'Scheduled' | 'Suspended'

function normalized(value: unknown) {
  return String(value ?? '').normalize('NFD').replace(/[\u0300-\u036f]/g, '').toLowerCase()
}

function isSuspended(task: TaskItem) {
  const value = normalized(task.suspended)
  return value === '1' || value === '2' || value === 'true' || value === 'sim' || value.includes('suspend')
}

function displayTaskName(task: TaskItem) {
  if (!task.taskClass.startsWith('%SYS.Task.')) return task.name
  const className = task.taskClass.split('.').at(-1) || task.name
  return className
    .replace(/([A-Z]+)([A-Z][a-z])/g, '$1 $2')
    .replace(/([a-z0-9])([A-Z])/g, '$1 $2')
}

function displayResult(task: TaskItem) {
  const value = normalized(task.lastResult)
  if (!task.lastFinished && !value) return 'Not run'
  if (value.includes('success') || value.includes('sucesso')) return 'Success'
  if (value.includes('error') || value.includes('erro') || value.includes('fail')) return 'Error'
  return task.lastFinished ? 'Completed' : 'Pending'
}

function displayNextRun(task: TaskItem) {
  const date = String(task.nextScheduledDate || '').trim()
  const time = String(task.nextScheduledTime || '').trim()
  if (!date || normalized(date).includes('nao') || normalized(date).includes('not')) return 'Not scheduled'
  return [date, time].filter(Boolean).join(' ')
}

function taskState(task: TaskItem) {
  if (isSuspended(task)) return 'Suspended'
  return displayNextRun(task) === 'Not scheduled' ? 'On demand' : 'Scheduled'
}

function managerLabel(status: number) {
  if (status === 1) return 'Manager running'
  if (status === 2) return 'Manager suspended'
  return 'Manager stopped'
}

export default function TasksPage() {
  const [tasks, setTasks] = useState<TaskItem[]>([])
  const [managerStatus, setManagerStatus] = useState(0)
  const [filter, setFilter] = useState<Filter>('All')
  const [query, setQuery] = useState('')
  const [loading, setLoading] = useState(true)
  const [error, setError] = useState('')
  const [selected, setSelected] = useState<TaskDetail | null>(null)
  const [detailLoading, setDetailLoading] = useState(false)
  const [actionLoading, setActionLoading] = useState(false)
  const [actionMessage, setActionMessage] = useState('')

  const loadTasks = () => getTasks().then((response) => {
    setTasks(response.data.tasks)
    setManagerStatus(response.data.managerStatus)
  })

  useEffect(() => {
    loadTasks()
      .catch((reason: Error) => setError(reason.message || 'The task inventory could not be loaded.'))
      .finally(() => setLoading(false))
  }, [])

  const openTask = async (id: number) => {
    setDetailLoading(true)
    setActionMessage('')
    try {
      const response = await getTaskDetail(id)
      setSelected(response.data)
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : 'Task details could not be loaded.')
    } finally {
      setDetailLoading(false)
    }
  }

  const runAction = async (action: 'run' | 'suspend' | 'resume') => {
    if (!selected) return
    const label = action === 'run' ? 'run this task now' : `${action} this task`
    if (!window.confirm(`Do you want to ${label}?`)) return
    setActionLoading(true)
    setActionMessage('')
    try {
      const response = await performTaskAction(selected.id, action)
      setActionMessage(response.data.message)
      await loadTasks()
      const detail = await getTaskDetail(selected.id)
      setSelected(detail.data)
    } catch (reason) {
      setActionMessage(reason instanceof Error ? reason.message : 'The task action failed.')
    } finally {
      setActionLoading(false)
    }
  }

  const visible = useMemo(() => tasks.filter((task) => {
    if (filter === 'Scheduled' && taskState(task) !== 'Scheduled') return false
    if (filter === 'Suspended' && !isSuspended(task)) return false
    return `${displayTaskName(task)} ${task.name} ${task.namespace} ${task.taskClass}`.toLowerCase().includes(query.trim().toLowerCase())
  }), [filter, query, tasks])

  const suspendedCount = tasks.filter(isSuspended).length
  const scheduledCount = tasks.filter((task) => taskState(task) === 'Scheduled').length
  const completedCount = tasks.filter((task) => Boolean(task.lastFinished)).length

  return (
    <>
      <section className="page-intro tasks-intro">
        <div><p className="eyebrow">TASK MANAGER</p><h2>Scheduled tasks</h2><p>Review native IRIS tasks, execution state, schedules, and recent results.</p></div>
        <div className="permission-stats"><span><strong>{tasks.length}</strong>Tasks</span><span><strong>{scheduledCount}</strong>Scheduled</span><span><strong>{suspendedCount}</strong>Suspended</span></div>
      </section>

      <section className="data-panel">
        <div className="data-toolbar">
          <div className="tabs">{(['All', 'Scheduled', 'Suspended'] as Filter[]).map((name) => <button className={filter === name ? 'active' : ''} type="button" onClick={() => setFilter(name)} key={name}>{name}</button>)}</div>
          <div className={`manager-state ${managerStatus === 1 ? 'running' : ''}`}>● {managerLabel(managerStatus)}</div>
          <label className="search-box"><span>⌕</span><input aria-label="Search tasks" value={query} onChange={(event) => setQuery(event.target.value)} placeholder="Search tasks…" /></label>
        </div>
        {loading && <div className="data-state">Loading scheduled tasks…</div>}
        {error && <div className="data-state error-state">{error}</div>}
        {!loading && !error && <div className="table-wrap"><table>
          <thead><tr><th>Task</th><th>Status</th><th>Namespace</th><th>Next run</th><th>Last finished</th><th>Result</th><th>Task class</th><th>Actions</th></tr></thead>
          <tbody>{visible.map((task) => {
            const state = taskState(task)
            const result = displayResult(task)
            return <tr key={task.id}>
              <td className="primary-cell"><span className="task-name"><i>#{task.id}</i>{displayTaskName(task)}</span></td>
              <td><span className={`status-chip ${state === 'Suspended' ? 'suspended' : state === 'Scheduled' ? 'enabled' : ''}`}>{state}</span></td>
              <td><span className="namespace-tag">{task.namespace || '—'}</span></td>
              <td>{displayNextRun(task)}</td>
              <td>{task.lastFinished || 'Never'}</td>
              <td><span className={`result-label ${result === 'Error' ? 'error' : ''}`}>{result}</span></td>
              <td className="mono routine-cell">{task.taskClass || '—'}</td>
              <td><button className="row-action" type="button" onClick={() => openTask(task.id)}>View</button></td>
            </tr>
          })}</tbody>
        </table>{!visible.length && <div className="data-state">No matching tasks.</div>}</div>}
        {!loading && !error && <div className="panel-footnote">{completedCount} tasks have recorded execution history. Only MEUPORTAL tasks can be changed.</div>}
      </section>
      {detailLoading && <div className="modal-backdrop"><div className="permission-modal"><div className="data-state">Loading task details…</div></div></div>}
      {selected && !detailLoading && <div className="modal-backdrop" onMouseDown={() => setSelected(null)}>
        <article className="permission-modal application-modal" onMouseDown={(event) => event.stopPropagation()}>
          <button className="modal-close" type="button" aria-label="Close" onClick={() => setSelected(null)}>×</button>
          <p className="eyebrow">TASK #{selected.id}</p>
          <h3>{displayTaskName(selected)}</h3>
          <p className="modal-description">{selected.taskClass.startsWith('%SYS.Task.') ? 'Native IRIS scheduled task.' : (selected.description || 'No description is available for this task.')}</p>
          <div className="detail-grid">
            <span><small>STATUS</small><b>{taskState(selected)}</b></span>
            <span><small>NAMESPACE</small><b>{selected.namespace || '—'}</b></span>
            <span><small>SCHEDULING MODE</small><b>{taskState(selected)}</b></span>
            <span><small>NEXT RUN</small><b>{displayNextRun(selected)}</b></span>
            <span><small>RUN AS USER</small><b>{selected.runAsUser || '—'}</b></span>
            <span><small>PRIORITY</small><b>{selected.priority || '—'}</b></span>
            <span><small>LAST FINISHED</small><b>{selected.lastFinished || 'Never'}</b></span>
            <span><small>LAST RESULT</small><b>{displayResult(selected)}</b></span>
          </div>
          <div className="detail-section">
            <div className="detail-heading"><div><small>TASK CLASS</small><h4 className="mono">{selected.taskClass || '—'}</h4></div></div>
            {Boolean(selected.manageable) ? <div className="task-actions">
              <button className="row-action" type="button" disabled={actionLoading} onClick={() => runAction('run')}>Run now</button>
              {isSuspended(selected)
                ? <button className="row-action" type="button" disabled={actionLoading} onClick={() => runAction('resume')}>Resume</button>
                : <button className="row-action" type="button" disabled={actionLoading} onClick={() => runAction('suspend')}>Suspend</button>}
            </div> : <p className="modal-description">{selected.protectionReason}</p>}
            {actionMessage && <p className="action-message">{actionMessage}</p>}
          </div>
        </article>
      </div>}
    </>
  )
}
