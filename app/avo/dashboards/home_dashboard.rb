class Avo::Dashboards::HomeDashboard < Avo::Dashboards::BaseDashboard
  self.id = "home_dashboard"
  self.name = "Home"
  self.description = "AI Agent Orchestrator Admin Dashboard"
  self.grid_cols = 3

  def cards
    card Avo::Cards::MetricCard, 
         label: "Total Users",
         description: "Registered users in the system",
         cols: 1
    
    card Avo::Cards::MetricCard,
         label: "Active Epics", 
         description: "Epics currently running",
         cols: 1
    
    card Avo::Cards::MetricCard,
         label: "Completed Tasks",
         description: "Successfully completed tasks",
         cols: 1
  end
end
