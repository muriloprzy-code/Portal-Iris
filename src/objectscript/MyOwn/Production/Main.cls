Class MyOwn.Production.Main Extends Ens.Production
{

XData ProductionDefinition
{
<Production Name="MyOwn.Production.Main" TestingEnabled="true" LogGeneralTraceEvents="false">
  <Description>MyOwn agent decision workflows with human-confirmed state changes.</Description>
  <ActorPoolSize>2</ActorPoolSize>
  <Item Name="HealthMonitor" Category="Services" ClassName="MyOwn.Production.Service.HealthMonitor" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Monitors health anomalies." LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="CallInterval">60</Setting>
  </Item>
  <Item Name="TaskWatcher" Category="Services" ClassName="MyOwn.Production.Service.TaskWatcher" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Monitors failed tasks." LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="CallInterval">120</Setting>
    <Setting Target="Adapter" Name="TaskNamespace">MYOWN</Setting>
    <Setting Target="Adapter" Name="HistoryRows">200</Setting>
    <Setting Target="Adapter" Name="FailureThreshold">3</Setting>
  </Item>
  <Item Name="LogWatcher" Category="Services" ClassName="MyOwn.Production.Service.LogWatcher" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Monitors serious log entries." LogTraceEvents="false" Schedule="">
    <Setting Target="Adapter" Name="CallInterval">120</Setting>
    <Setting Target="Adapter" Name="MinSeverity">2</Setting>
    <Setting Target="Adapter" Name="MaxEntries">10</Setting>
  </Item>
  <Item Name="AccessRequestService" Category="Services" ClassName="MyOwn.Production.Service.AccessRequest" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Accepts access request events from the portal." LogTraceEvents="false" Schedule="" />
  <Item Name="ExecutionFeedbackService" Category="Services" ClassName="MyOwn.Production.Service.ExecutionFeedback" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Closes the execution feedback loop." LogTraceEvents="false" Schedule="" />
  <Item Name="TriageProcess" Category="Processes" ClassName="MyOwn.Production.Process.Triage" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Coordinates incident triage decisions." LogTraceEvents="false" Schedule="" />
  <Item Name="AccessProcess" Category="Processes" ClassName="MyOwn.Production.Process.Access" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Coordinates access request decisions." LogTraceEvents="false" Schedule="" />
  <Item Name="AgentGateway" Category="Operations" ClassName="MyOwn.Production.Operation.AgentGateway" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Selects the configured decision engine." LogTraceEvents="false" Schedule="" />
  <Item Name="ProposalStore" Category="Operations" ClassName="MyOwn.Production.Operation.ProposalStore" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Validates persisted proposals." LogTraceEvents="false" Schedule="" />
  <Item Name="Notifier" Category="Operations" ClassName="MyOwn.Production.Operation.Notifier" PoolSize="1" Enabled="true" Foreground="false" InactivityTimeout="0" Comment="Stores execution feedback notifications." LogTraceEvents="false" Schedule="" />
</Production>
}

}
