#Load Libraries

library(jsonlite)
library(tidyverse)
library(leaflet)
library(shiny)
library(sf)
library(shinyWidgets)
library(tidycensus)
library(viridis)
library(ggplot2)
library(R.utils)
library(plotly)
library(htmlwidgets)
library(stringr)
library(tidycensus)
library(rsconnect)

#Get MDOT/MVA Electric/Plug In Hybrid Data
elx_county <- read_csv("elxg.csv")

plug_in <- read_csv("pig.csv")%>%
  rename("county" = "date")

#Get Census Shapefiles for County and Tract Income and Population
income_df <- st_read("incomes.shp") %>%
  st_transform(crs = "+proj=longlat +datum=WGS84")

pop_df <- st_read("tract_pop_new.shp") %>%
  st_transform(crs = "+proj=longlat +datum=WGS84")

pop_county_df <- st_read("pop_county.shp") %>%
  st_transform(crs = "+proj=longlat +datum=WGS84")

income_county_df <- st_read("income_county.shp") %>%
  st_transform(crs = "+proj=longlat +datum=WGS84")

#Get and Prepare Cleaned Station Data from DOE
clean_stations <- read_csv("charging513.csv")

clean_stations <- clean_stations[complete.cases(clean_stations$open_date), ]
clean_stations <- clean_stations[!(clean_stations$id == 148299), ]

clean_stations <- clean_stations %>%
  mutate(
    latitude = ifelse(id == 238038, 38.9976532, latitude),
    longitude = ifelse(id == 238038, -77.0341977, longitude),
    county = ifelse(id == 238038, "Montgomery County", county)
  )

#Get Maryland Shapefile for Map Outline
md_shp <- st_read("https://raw.githubusercontent.com/frankrowe/maryland-geojson/master/maryland.geojson") %>%
  st_transform(crs = "+proj=longlat +datum=WGS84")


########Build the Shiny App UI
ui <- fluidPage(
  navbarPage(
    "EVs in MD",
    tabPanel(
      "Station Map",
      h2("Electric Vehicle Charging Stations in Maryland ⚡"),
      fluidRow(
        column(
          width = 3,
          tags$p(
            HTML("There are more than 1,500 electric vehicle charging stations in Maryland, according to data extracted in May from the U.S. Department of Energy's API.<br><br> Explore stations and demographics below.")
          ),
          selectInput(
            inputId = "county",
            label = "Select Jurisdiction",
            choices = c("All", sort(unique(clean_stations$county)))
          ),
          selectInput(
            inputId = "demogs",
            label = "Explore Demographics by Census Tract",
            choices = c("Clear tract variables", "Income (Census Tract)", "Population (Census Tract)")
          ),
          selectInput(
            inputId = "county_demogs",
            label = "Explore Demographics by County",
            choices = c("Clear county variables", "Income (County)", "Population (County)")
          ),
          p("⚠️ Tip: You can only view one demographic overlay at a time. Clear out extraneous variables for best results.")
        ),
        column(
          width = 9,
          leafletOutput("mymap")
        )
      ),
      hr(),
      fluidRow(
        column(
          width = 12,
          dataTableOutput("stationTable")
        ),
      hr(),
      p(
        HTML(
          "Data Sources: U.S. Census, ", "<a href='https://developer.nrel.gov/docs/transportation/alt-fuel-stations-v1/'>U.S. Department of Energy</a>", 
          "<br>Learn more and <a href='https://github.com/rinatorch/ev_shiny_app/blob/main-branch/README.md'>explore the code on GitHub.</a>")),
      
      
      )
    ),

    tabPanel(
      "Data Insights",
      h2("Zooming Out 🔎"),
     
      fluidRow(
        column(
          width = 3,
          p(
            HTML("<br>Baltimore City and Montgomery and Prince George's counties each have more than 200 electric vehicle charging stations, federal data showed in May.
            <br><br>It's important to note the role population plays in these figures. Montgomery and Prince George's counties are the most populous Maryland counties. Meanwhile, Somerset and Caroline counties each have populations below 50,000.", "<br><br>The scatterplot, at right, accounts for population. Hover over the dots to learn more.", "<br><br>Below, explore where electric and plug-in hybrid vehicles are registered.")
          )
          ),
  
        column(
          width = 9,
                plotlyOutput("scatterplot")
            
        ),

        fluidRow(

        column(
          width = 12,
          h2("Electric Vehicle Registrations 🚗"),
          p("The state of Maryland maintains a dataset of electric vehicle registrations by jurisdiction. The charts show a monthly count of plug-in or electric vehicles over time."),
          tabsetPanel(
            id = "tabset",
            tabPanel(
              "Electric Vehicles",
              plotlyOutput("countyElxLines")
            ),
            tabPanel(
              "Plug-In Hybrid Vehicles",
              plotlyOutput("plugLines")
            ),
          hr(),
          p(
            HTML(
              "<br><br>Data Sources: <a href='https://opendata.maryland.gov/Transportation/MDOT-MVA-Electric-and-Plug-in-Hybrid-Vehicle-Regis/qtcv-n3tc'>Maryland Department of Transportation/Maryland Motor Vehicle Administration,</a>", "U.S. Census, ", "<a href='https://developer.nrel.gov/docs/transportation/alt-fuel-stations-v1/'>U.S. Department of Energy</a>",
              "<br>Learn more and <a href='https://github.com/rinatorch/ev_shiny_app/blob/main-branch/README.md'>explore the code on GitHub.</a>")),
          

        )
          )
        )
      )
    )
  ))


#Prepare palettes for map overlays -- Tract Level
pop_pal <- colorNumeric(
  palette = "viridis",
  domain = pop_df$pop, na.color = NA)

income_pal <- colorNumeric(
  palette = "viridis",
  domain = income_df$income, na.color = NA)

#Prepare palettes for map overlays -- County Level
pop_pal_county <- colorNumeric(
  palette = "viridis",
  domain = pop_county_df$estimate, na.color = NA)

income_pal_county <- colorNumeric(
  palette = "viridis",
  domain = income_county_df$estimate, na.color = NA)


########Build the Shiny App Server
server <- function(input, output, session) {

#Develop County Bar Chart on Data Insights Page

    output$scatterplot<- renderPlotly({
    
      station_county_table <- 
        clean_stations %>% 
        count(county)%>%
        arrange(desc(n))%>%
        mutate(county = str_replace(county, "Saint", "St."))
      
      #populations
      pop_county_df <- get_acs(geography = "county", 
                               variables = "B01003_001", 
                               state = "MD",
                               geometry = FALSE)%>%
        rename("pop" = "estimate")%>%
        rename("county" = "NAME")
      pop_county_df$county = str_to_title(pop_county_df$county)
      
      pop_county_df$county<-gsub(", Maryland","",as.character(pop_county_df$county))
      
      #join
      county_pop <- inner_join(pop_county_df, station_county_table, by = "county")%>%
        select(county, n, pop)
      
      #plot
      
      pop_county_plot <- ggplot(county_pop, aes(text = paste0('<b>Jurisdiction</b>: ', county, '<br>', '<b>Population</b>: ', pop, '<br>', '<b>Station Count</b>: ', n))) +
        geom_point(aes(x = pop, y = n), size = 3, color='#2A788EFF') +
        theme_minimal()+
        labs(
          title="Electric Vehicle Charging Stations Locations, by Population and Station Count", 
          x="Population", 
          y="Station Count"
        )
      
      
      plotly_pop_plot <- ggplotly(pop_county_plot, tooltip = "text") %>%
        layout(hoverlabel = list(namelength = -1))
      
      plotly_pop_plot

  })
  
  
  
#Develop County EVs Line Chart on Data Insights Page
  
  output$countyElxLines<- renderPlotly({
    
    transformed_dates <- mdy(elx_county$Date, format = "%m-%d-%Y")
    
    # Remove the additional row
    if (length(transformed_dates) > nrow(elx_county)) {
      transformed_dates <- transformed_dates[1:nrow(elx_county)]
    }
    
    # Assign the transformed dates back to the Date column
    elx_county$Date <- transformed_dates
    
    
    elx_linechart <- ggplot(elx_county, aes(x = Date, y = Count, group = county, color = county)) +
      geom_line(size = 1.25, aes(text = paste0('<b>Jurisdiction</b>: ', county, '<br>',
                                               '<b>Date</b>: ', format(Date, "%B %Y"), '<br>',
                                               '<b>Count</b>: ', Count)))+
      labs(x = "Date", y = "Count", title = "Electric Vehicle Count, by Jurisdiction", color = "Jurisdiction") +
      theme_minimal()
    
    plotly_elx_chart <- ggplotly(elx_linechart, tooltip = "text") %>%
      layout(hoverlabel = list(namelength = -1))
    
    plotly_elx_chart
 
    
  })
  
#Develop County Plug In Vehicles Line Chart on Data Insights Page

  output$plugLines<- renderPlotly({
  
  plug_in$Date <- mdy(plug_in$Date)
  
  plug_linechart <- ggplot(plug_in, aes(x = Date, y = Count, group = county, color = county)) +
    geom_line(size = 1.25, aes(text = paste0('<b>Jurisdiction</b>: ', county, '<br>',
                                             '<b>Date</b>: ', format(Date, "%B %Y"), '<br>',
                                             '<b>Count</b>: ', Count)))+
    labs(x = "Date", y = "Count", title = "Plug-In Hybrid Vehicle Count, by Jurisdiction", color = "Jurisdiction") +
    theme_minimal()
  
  plotly_plug_chart <- ggplotly(plug_linechart, tooltip = "text") %>%
    layout(hoverlabel = list(namelength = -1))
  
  plotly_plug_chart
  
  })
  
#Create Server Logic for Filtering by County on Map Page
  
  filtered_county <- reactive({
    if (input$county == "All") {
      return(clean_stations$county)
    } else {
      return(input$county)
    }
  })
  
#Begin to Develop Map  
  
  output$mymap <- renderLeaflet({
    leaflet() %>%
      addProviderTiles(providers$CartoDB.Positron) %>%
      setView(lng = -76.641273, lat = 39.045753, zoom = 7)
  })

  
#Create Server Logic for Filtering Jurisdiction, Tract and County Demographics
  
  observeEvent(c(input$county, input$demogs, input$county_demogs), {
    if (input$county == "All") {
      filtered_stations <- clean_stations
    } else {
      filtered_stations <- clean_stations %>%
        filter(county == filtered_county())
    }
    
#Select Table Fields
    
    output$stationTable <- renderDataTable({
      filtered_stations[, c("station_name", "street_address", "city", "state", "zip", "county")]
   
    })
    
#Develop Map Markers, State Outline
    
    leafletProxy("mymap") %>%
      clearMarkers() %>%
      clearControls() %>%
      clearShapes() %>%
      addPolylines(
        data = md_shp,
        weight = 2,
        color = "gray"
      ) %>%
      addCircleMarkers(
        color = 'black',
        radius = 2,
        data = filtered_stations
      )
    
#Create Server Logic for County, Tract selections
    
  if (input$demogs == "Population (Census Tract)") {
    leafletProxy("mymap") %>%
      clearShapes() %>%
      addPolygons(
        data = pop_df,
        group = "Population by Census Tract",
        color = ~pop_pal(pop),
        fillOpacity = 0.5,
        stroke = FALSE
      ) %>%
      addLegend(
        "bottomleft",
        pal = pop_pal,
        values = pop_df$pop,
        title = "Population Levels (Census Tract)"
      )
  } else if (input$demogs == "Income (Census Tract)") {
    leafletProxy("mymap") %>%
      clearShapes() %>%
      addPolygons(
        data = income_df,
        group = "Income by Census Tract",
        color = ~income_pal(income),
        fillOpacity = 0.5,
        stroke = FALSE
      ) %>%
      addLegend(
        "bottomleft",
        pal = income_pal,
        values = income_df$income,
        title = "Income Levels (Census Tract)"
      )
  }
  
  if (input$county_demogs == "Population (County)") {
    leafletProxy("mymap") %>%
      clearShapes() %>%
      addPolygons(
        data = pop_county_df,
        group = "Population by County",
        color = ~pop_pal_county(estimate),
        fillOpacity = 0.5,
        stroke = FALSE
      ) %>%
      addLegend(
        "bottomleft",
        pal = pop_pal_county,
        values = pop_county_df$estimate,
        title = "Population Levels (County)"
      )
  } else if (input$county_demogs == "Income (County)") {
    leafletProxy("mymap") %>%
      clearShapes() %>%
      addPolygons(
        data = income_county_df,
        group = "Income by County",
        color = ~income_pal_county(estimate),
        fillOpacity = 0.5,
        stroke = FALSE
      ) %>%
      addLegend(
        "bottomleft",
        pal = income_pal_county,
        values = income_county_df$estimate,
        title = "Income Levels (County)"
      )
  }
})
}

#Launch!
shinyApp(ui, server)




 




