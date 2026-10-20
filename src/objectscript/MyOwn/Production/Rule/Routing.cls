/// Deterministic first-stage routing for incident messages.
/// Unknown or empty sources are discarded before they can reach an agent engine.
Class MyOwn.Production.Rule.Routing Extends Ens.Rule.Definition
{

Parameter RuleAssistClass = "Ens.Rule.GeneralBusinessRuleAssist";

XData RuleDefinition [ XMLNamespace = "http://www.intersystems.com/rule" ]
{
<ruleDefinition alias="" context="MyOwn.Production.Msg.IncidentEvent" production="MyOwn.Production.Main">
  <ruleSet name="" effectiveBegin="" effectiveEnd="">
    <rule name="Route known operational sources" disabled="false">
      <when condition="(Source=&quot;health&quot;)||(Source=&quot;task&quot;)||(Source=&quot;log&quot;)||(Source=&quot;manual&quot;)||(Source=&quot;simulate&quot;)||(Source=&quot;integration-test&quot;)">
        <return>"incident-triage"</return>
      </when>
      <otherwise>
        <return>"drop"</return>
      </otherwise>
    </rule>
  </ruleSet>
</ruleDefinition>
}

}
