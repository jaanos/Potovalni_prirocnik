library(shiny)
library(dplyr)
library(RPostgreSQL)
library(datasets)
#library(chron)




source("../auth_public.R",encoding='UTF-8')


shinyServer(function(input,output){
  conn <- src_postgres(dbname = db, host = host,
                       user = user, password = password)
  letalisca <- (tbl(conn, "letalisca_koordinate"))
  url_tabela <- (tbl(conn, "url_tabela"))
  leti <-(tbl(conn, "leti"))
  slo_mesta <-(tbl(conn, "slo_mesta_koordinate"))
  mesta <- slo_mesta %>% select(mesto) %>% data.frame()
  #
  query <- "SELECT a.*, b.url FROM leti a, url_tabela b where a.ponudnik=b.prevoznik"
  dsub2 <- tbl(conn, sql(query))
  dsub <- dsub2 %>% data.frame()
  
  #dsub$url <- paste0("<a href='",dsub$url,"'>",dsub$url,"</a>")
  
  ###tabela_test<-dbGetQuery(conn, "SELECT a.*, b.ponudnik FROM leti a, url_tabela b where a.prevoznik=b.ponudnik"))
  Encoding(mesta$mesto) <- "UTF-8"
  output$mesto<-renderUI({selectInput(inputId="odhod", label = "od kje boste potovali?",mesta$mesto)})
  #
  #output$dsub<-renderTable({dsub})

  pretvornik<-function(km){
    Lat <-  km/110.54
    Lon <- km/(111.320*cos(Lat))
    c(Lat, Lon)
  }
  dobi_omejitve<-function(kraj,km){
    a<-slo_mesta %>% filter(mesto == kraj) %>% data.frame()
    lat<-c(a$sirina + pretvornik(km)[1],a$sirina - pretvornik(km)[1])
    lon<-c(a$dolzina + pretvornik(km)[2],a$dolzina - pretvornik(km)[2])
    c(lat, lon)
  }
  primerna_letalisca<-function(kraj,km){
    b<-max(dobi_omejitve(kraj,km)[1],dobi_omejitve(kraj,km)[2])
    c<-min(dobi_omejitve(kraj,km)[1],dobi_omejitve(kraj,km)[2])
    d<-max(dobi_omejitve(kraj,km)[3],dobi_omejitve(kraj,km)[4])
    e<-min(dobi_omejitve(kraj,km)[3],dobi_omejitve(kraj,km)[4])
    a<-letalisca %>% filter(sirina < b
                            & sirina > c
                            & dolzina < d
                            & dolzina > e) %>%data.frame()
  }
  mozne_destinacije<-function(kraj,km){
    a<-primerna_letalisca(kraj,km)$letalisce
    #pr.leti<-subset(data.frame(leti), data.frame(leti)$odhod %in% a)
    pr.leti<-subset(data.frame(dsub), data.frame(dsub)$odhod %in% a)
  }
  output$izbira<-renderUI({
    if(input$goButton){
      selectInput(inputId="destinacija", label="Izberi destinacijo",unique(mozne_destinacije(input$odhod,input$kilometri)$prihod))}})
  poisci_let<-function(kraj,km,destinacija){
    a<-mozne_destinacije(kraj,km) %>% filter(prihod == destinacija)
    }
  najugodnejsi.let<-function(kraj, km, destinacija){
    a<-poisci_let(kraj,km,destinacija)
    b<-filter(a,cena==min(a$cena))
  }
  poisci.povezavo<-function(kraj, km, destinacija){
    a<-najugodnejsi.let(kraj, km, destinacija)$ponudnik[1]
    b<-filter(data.frame(url_tabela), prevoznik==a)$url
  }
  izbira<-function(){
    neki<-switch(input$ponudnik, najcenejsi = TRUE, ostali = FALSE)
  }

 # output$mozni.leti<-renderTable({if(input$goButton & izbira()==FALSE){poisci_let(input$odhod, input$kilometri, input$destinacija)}})
  output$dsub<-renderTable({if(input$goButton & izbira()==FALSE){poisci_let(input$odhod, input$kilometri, input$destinacija)}})


   output$naslov<-renderUI({HTML(if(input$goButton & izbira()){"<b> <body bgcolor='#cce6ff'> <h2> <font color='#660033'> Najcenejši let: </font> </h2> </body> </b>"})})
   output$cena<-renderUI({if(input$goButton & izbira()){HTML(paste0("<body bgcolor='#cce6ff'><b>Cena:  </b>", najugodnejsi.let(input$odhod, input$kilometri, input$destinacija)$cena[1]," €</body>"))}})
   output$krajodhoda<-renderUI({if(input$goButton & izbira()){HTML(paste0("<b>Kraj odhoda:  </b>", najugodnejsi.let(input$odhod, input$kilometri, input$destinacija)$odhod[1]))}})
   output$ponudnik<-renderUI({if(input$goButton & izbira()){HTML(paste0("<b>Ponudnik:  </b>", najugodnejsi.let(input$odhod, input$kilometri, input$destinacija)$ponudnik[1]))}})
   output$povezava<-renderUI({if(input$goButton & izbira()){HTML(paste0("<b>Povezava do ponudnika: </b> <a href='",
                                          poisci.povezavo(input$odhod, input$kilometri, input$destinacija),
                                          "'>",poisci.povezavo(input$odhod, input$kilometri, input$destinacija), "</a>"))}})

})


