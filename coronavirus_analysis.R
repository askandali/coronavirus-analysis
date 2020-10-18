#Load libraries
library(stringdist)
library(tidyverse)
library(stringi)
library(readxl)
library(writexl)
library(quanteda)
library(igraph)
library(ggraph)
Sys.setlocale("LC_CTYPE", "utf-8")

#Insert data of case 1 and ATC dataset
case1_input<-read_excel("data/data.xlsx", sheet = "Case 1", skip = 3)
atc_input<-read.csv("data/ATC.csv",header =T,sep = ";")

# case1 / atc dataframes
c1<-data.frame(case1_input)
atc<-data.frame(atc_input)

# make atc data strings to lower case
atc_substances<-tolower(as.character(unlist(atc["Preferred.Label"],use.names = F)))
# keep the unique substances
case1_unique_substance<-unique(as.character(unlist(c1["Source.Concept"])))

## TASK 1

# Function that identifies which substances are included in ATC's list
get_matched_substances <- function(unique_sub, atc_sub){
  set<-NULL
  set<-list()
  finalset<-NULL
  finalset<-list()

  for (i in unique_sub){
    ratio_array<-NULL
    temp_ratio<-0
    temp_val<-""
    for (val in atc_sub){
      splitted_val <-strsplit(val, "\\s+")[[1]]
      
      # check if value matches the first word
      if (i == splitted_val[1]){
        finalset[[i]]<-val
      }
      # check if value matches the rest words
      else if (i %in% splitted_val[2:length(splitted_val)]){
        finalset[[i]]<-c(finalset[[i]],val)
      } 
      else {
        # find similarity based on 'jw' method
        res = stringsim(i,val,method='jw')
        
        # keep ones with ratio > 0.9  
        if (res > 0.9) {
          temp_ratio=res
          temp_val=val
          set[[i]]<-c(set[[i]],val)
          ratio_array<-c(ratio_array,res)
        }
      }
    }
    
    # assign values to the final set
    if (length(set[[i]])>0){
      index<-which.max(ratio_array)
      finalset[[i]]<-c(finalset[[i]],set[[i]][index])
    }
    if (i %in% finalset[[i]]){
      finalset[[i]]<- i
    }
  }
  return(finalset)
}

# Call the function with the case1 data
case1_finalset<-get_matched_substances(case1_unique_substance,atc_substances)


# List To dataframe
case1_identified_drugs <- data.frame(cbind(names(case1_finalset),stri_list2matrix(case1_finalset, byrow = F)[1,]), stringsAsFactors=FALSE)
names(case1_identified_drugs)<-c("Drugs Case 1","Identified Value in ATC")
#write_xlsx(case1_identified_drugs,"output/Identified_Drugs_case_1.xlsx")

#### VISUALIZATION - WORD CLOUD

indexes_1<-NULL
for(dr in case1_identified_drugs[,1]){
  indexes_1<-c(indexes_1,which(c1[,2]==dr))
}

# Keep all identified drugs
drugs_match<-c1[indexes_1,2]
drugs<-as.character(drugs_match)

# Create corpus
drugs_corpus <- corpus(drugs)

# Create tokens
drugs_tokens<-tokens(drugs_corpus, remove_numbers = TRUE, 
                     remove_punct = TRUE, remove_symbols = TRUE, what = "sentence",
                     include_docvars = TRUE)

drugs_dfm<-dfm(drugs_tokens)
set.seed(100)
# create word cloud based on frequency
textplot_wordcloud(drugs_dfm, min_count=1, color = RColorBrewer::brewer.pal(4, "Dark2"), min_size =0.7)

## TASK 2
### Authors - KOL 

### Split Authors By Comma
drugs_identified<-case1_identified_drugs[,1]

## index of the identified drugs
indexes<-NULL
authors<-NULL

# Extract the all authors per substance
for(d in drugs_identified){
  indexes<-which(c1["Source.Concept"]==d)
  vec_authors<-NULL
  for(ind in indexes){
    row_authors<- as.character(c1[ind,"Author.s."])
    vec_authors<- c(vec_authors,unlist(strsplit(row_authors, ",")))
  }
  # sort with decreasing order and keep the 10 first
  authors<-cbind(authors,names(sort(table(vec_authors),decreasing = T)[1:10]))
}

df_KOL<-data.frame(authors)
names(df_KOL) <- drugs_identified

#write_xlsx(df_KOL,"output/Top10_KOL.xlsx")


## TASK 3

# Insert data of case 2
case2_input<-read_excel("data/data.xlsx", sheet = "Case 2", skip = 3)
c2<-data.frame(case2_input)

# keep the unique
case2_unique_substances<-unique(tolower(as.character(c2[,1])))

# Call the function with the case2 data
case2_finalset<-get_matched_substances(case2_unique_substances,atc_substances)

#List to data frame
case2_identified_drugs <- data.frame(stri_list2matrix(case2_finalset, byrow = F), stringsAsFactors=FALSE)
names(case2_identified_drugs)<-names(case2_finalset)

case2_identified_drugs <- data.frame(cbind(names(case2_finalset),stri_list2matrix(case2_finalset, byrow = F)[1,]), stringsAsFactors=FALSE)
names(case2_identified_drugs)<-c("Drugs Case 2","Identified Value in ATC")

#write_xlsx(case2_identified_drugs,"output/Identified_Drugs_case2.xlsx")


drugs_identified<-case2_identified_drugs[,1]

#keep the indexes where the identified drugs are in the case2 dataset
indexes<-NULL
for(d in drugs_identified){
  indexes<-c(indexes,which(tolower(c2[,1])==d))
}

#create a data frame with the identified drugs and the corresponding protain names, type and concept
task3<-cbind(tolower(as.character(c2[indexes,1])),as.character(c2[indexes,"node2.name"]),as.character(c2[indexes,"node2.categoriesUMLS"]),as.character(c2[indexes,"node3.name"]))
task3_df<-data.frame(task3)
names(task3_df)<-c("Drug","protein name","type","concept")
task3_df

proteins<-NULL
concept<-NULL
ind<-NULL

# keep the collection of proteins and coronavirus concepts per substance
for(drug in drugs_identified){
  ind<-which(task3[,1]==drug)
  proteins<-rbind(proteins,paste (unique(task3[ind,2]), sep = "  ", collapse =" | "))
  concept<-rbind(concept,paste (unique(task3[ind,4]), sep = "  ", collapse =" | "))
}

final_task3<-data.frame(cbind(drugs_identified, proteins, concept))
names(final_task3)<-c("Unique Substances Identified","Collection of Proteins", "Coronavirus Concepts")
#write_xlsx(final_task3,"output/Proteins & Consepts_per_Substance.xlsx")


## TASK 4

# find the substances that have same targets
target_drugs<-NULL
ind<-NULL
for(pr in unique(task3[,2])){
  ind<-which(task3[,2]==pr)
  target_drugs<-cbind(target_drugs,c(unique(task3[ind,1]))[1:50])
}

target_data<-data.frame(target_drugs)
names(target_data)<-unique(task3[,2])

#write_xlsx(target_data,"output/Proteins Clusters.xlsx")

## VISUALIZATION - CLUSTERS - NETWORK

# create igraph object
targets_igraph<-graph_from_data_frame(task3_df[1:2], directed = FALSE)
set.seed(123)

proteins<-task3_df[,2]
scale_func <- function(x){(x-min(x))/(max(x)-min(x))}

# set size of nodes and labels 
vSizes <- c(rep(1,length(unique(task3_df[,1]))),(scale_func(as.numeric(table(task3_df[,2])))+1)*10)
vSizes_name <- c(rep(1.7,length(unique(task3_df[,1]))),rep(3,length(unique(task3_df[,2]))))

ggraph(targets_igraph, layout = "fr") +
  geom_edge_link(alpha = 0.35) + 
  geom_edge_density(aes(fill = proteins)) +
  geom_node_point(color = 'thistle', size = vSizes, show.legend = FALSE) +
  geom_node_text(aes(label = name), size=vSizes_name, vjust = 1, hjust = 1) +
  scale_size_continuous(range = c(1,8)) +
  theme_graph() +
  theme(legend.position = 'left')