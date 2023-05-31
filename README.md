# Electric Vehicles in Maryland Shiny App ⚡

I developed an R Shiny app to explore electric vehicle station locations in Maryland through the lens of income and population levels. The app also includes visualizations of electric vehicle registrations by jurisdiction. Through this analysis, I take the pulse of the state of electric vehicles in Maryland, as automakers worldwide continue pressing for electric and consumers continue to consider making the shift.

## Methodology and Data

The focal point of this application is the interactive leaflet map of electric charging stations, backed by data from the the U.S. Department of Energy's API of electric vehicle stations. I zoomed in on an analysis of Maryland Electric Vehicle Charging Stations and added county and tract level features to explore the data. I included markers for each station and the ability to filter through demographic information at tract and county levels. I used tidycensus to extract the demographic information. The data table under the map updates based on the filters next to the map. The data was extracted from the app in mid-May.

The second page zooms out from the specificity of each station location. I used a combination of plotly and ggplot to develop a series of bar charts. The first chart shows electric vehicle charging stations by jurisdiction. The tab behind it shows a population by jurisdiction chart, designed to be a convenient reference point for users exploring the app.

The final section on the second page is backed by data from the state of Maryland. The data the state keeps on electric vehicle registrations by state is messy. The dataset included data for states, as well as Maryland counties. I selected just Maryland counties using a pivot table in Excel. 

## A little bit more about what inspired this

I couldn't find much research out there on the locations of electric vehicle charging stations, and I was curious to see what I could learn from including some demographic overlays in the mix. I hope this scratches the surface of a broader analysis on what determines the locations of electric vehicle stations and how that might inform who drives them. This analysis is also similar to a project I've done on [sports recreational deserts in Maryland](https://github.com/rinatorch/jour479x_fall_2022/blob/main/presentations/presentation2_new.Rmd), where I mapped Maryland sports venues and overlayed demographic information. In this undertaking, though, I dug deeper into creating a front-end, user-friendly application, which I hope will make this analysis easier for more people to explore. 

This app also happens to be my first Shiny app. Many thanks to the folks who create Shiny app tutorials online for the masses (and to Chat GPT for helping with debugging). In that vein, view my app script [here](https://github.com/rinatorch/ev_shiny_app/blob/main-branch/first_shiny_app/app_layout.r) and see how I accessed the API and grabbed Census data [here](https://github.com/rinatorch/ev_shiny_app/blob/main-branch/first_shiny_app/evs-in-md.rmd). I'm hoping this code can be a starting point for more electric vehicle analyses, but also for anyone trying to sort out how to incorporate leaflet, tables and plotly in R Shiny.

**Explore the app [here](https://rinatorch.shinyapps.io/evs-in-md/).** 


