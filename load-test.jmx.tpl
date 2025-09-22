<?xml version="1.0" encoding="UTF-8"?>
<jmeterTestPlan version="1.2" properties="5.0" jmeter="5.6.3">
  <hashTree>
    <TestPlan guiclass="TestPlanGui" testname="Function App Load Test">
      <elementProp name="TestPlan.user_defined_variables" elementType="Arguments" guiclass="ArgumentsPanel" testclass="Arguments" testname="User Defined Variables">
        <collectionProp name="Arguments.arguments">
          <elementProp name="function_host" elementType="Argument">
            <stringProp name="Argument.name">function_host</stringProp>
            <stringProp name="Argument.value">${function_host}</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
            <stringProp name="Argument.desc">Function App hostname</stringProp>
          </elementProp>
          <elementProp name="function_path" elementType="Argument">
            <stringProp name="Argument.name">function_path</stringProp>
            <stringProp name="Argument.value">${function_path}</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
            <stringProp name="Argument.desc">Function trigger path</stringProp>
          </elementProp>
          <elementProp name="virtual_users" elementType="Argument">
            <stringProp name="Argument.name">virtual_users</stringProp>
            <stringProp name="Argument.value">${virtual_users}</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
            <stringProp name="Argument.desc">Number of virtual users</stringProp>
          </elementProp>
          <elementProp name="ramp_up_seconds" elementType="Argument">
            <stringProp name="Argument.name">ramp_up_seconds</stringProp>
            <stringProp name="Argument.value">${ramp_up_seconds}</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
            <stringProp name="Argument.desc">Ramp up time in seconds</stringProp>
          </elementProp>
          <elementProp name="test_duration_seconds" elementType="Argument">
            <stringProp name="Argument.name">test_duration_seconds</stringProp>
            <stringProp name="Argument.value">${test_duration_seconds}</stringProp>
            <stringProp name="Argument.metadata">=</stringProp>
            <stringProp name="Argument.desc">Test duration in seconds</stringProp>
          </elementProp>
        </collectionProp>
      </elementProp>
    </TestPlan>
    <hashTree>
      <kg.apc.jmeter.threads.UltimateThreadGroup guiclass="kg.apc.jmeter.threads.UltimateThreadGroupGui" testname="Function App Load Test Group" enabled="true">
        <stringProp name="testclass">kg.apc.jmeter.threads.UltimateThreadGroup</stringProp>
        <elementProp name="ThreadGroup.main_controller" elementType="LoopController" guiclass="LoopControlPanel" testclass="LoopController">
          <stringProp name="LoopController.loops">${__P(iterations,-1)}</stringProp>
          <stringProp name="testname">LoopController</stringProp>
          <boolProp name="LoopController.continue_forever">false</boolProp>
        </elementProp>
        <collectionProp name="ultimatethreadgroupdata">
          <collectionProp name="ThreadSchedule1">
            <stringProp name="threadsnum">${virtual_users}</stringProp>
            <stringProp name="initdelay">0</stringProp>
            <stringProp name="startime">${ramp_up_seconds}</stringProp>
            <stringProp name="holdload">${test_duration_seconds}</stringProp>
            <stringProp name="shutdown">0</stringProp>
          </collectionProp>
        </collectionProp>
      </kg.apc.jmeter.threads.UltimateThreadGroup>
      <hashTree>
        <HTTPSamplerProxy guiclass="HttpTestSampleGui" testname="Function App HTTP Request">
          <elementProp name="HTTPsampler.Arguments" elementType="Arguments">
            <collectionProp name="Arguments.arguments"/>
          </elementProp>
          <stringProp name="HTTPSampler.implementation">HttpClient4</stringProp>
          <stringProp name="HTTPSampler.protocol">https</stringProp>
          <stringProp name="HTTPSampler.method">GET</stringProp>
          <stringProp name="HTTPSampler.path">${function_path}</stringProp>
          <stringProp name="HTTPSampler.domain">${function_host}</stringProp>
          <boolProp name="HTTPSampler.use_keepalive">true</boolProp>
          <boolProp name="HTTPSampler.follow_redirects">true</boolProp>
          <elementProp name="HTTPSampler.header_manager" elementType="HeaderManager" guiclass="HeaderPanel" testname="HTTP HeaderManager">
            <collectionProp name="HeaderManager.headers"/>
          </elementProp>
        </HTTPSamplerProxy>
        <hashTree>
          <HeaderManager guiclass="HeaderPanel" testname="HTTP HeaderManager">
            <collectionProp reference="../../../HTTPSamplerProxy/elementProp[2]/collectionProp"/>
          </HeaderManager>
          <hashTree/>
        </hashTree>
      </hashTree>
    </hashTree>
  </hashTree>
</jmeterTestPlan>