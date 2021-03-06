### STAT 6021 Final Project
### Predicting Lego Prices and  Themes
#Rohan Bapat,  rb2te
#Jennifer Cruser,   jc4pg
#Yi Hao,  yh8a
#Abhijith Mandya,  am6ku

install.packages("RCurl")

library(RCurl)
library(readr)
library(dplyr)

# Read input dataframes from Github
colors_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/colors.csv'))
inventories_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/inventories.csv'))
inventoryparts_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/inventory_parts.csv'))
inventorysets_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/inventory_sets.csv'))
partcategories_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/part_categories.csv'))
parts_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/parts.csv'))
sets_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/sets.csv'))
themes_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/themes.csv'))
prices_df <- read.csv(text =getURL('https://raw.githubusercontent.com/rohanbapat/STAT-6021-Project/master/AllLegoPrices.csv'))


###### 1. Data Merging #############

# Rename columns with same name but different definition
colnames(partcategories_df)[colnames(partcategories_df) == "name"] <- "partcat_name"
colnames(parts_df)[colnames(parts_df) == "name"] <- "part_name"
colnames(colors_df)[colnames(colors_df) == "name"] <- "color_name"
colnames(themes_df)[colnames(themes_df) == "name"] <- "sub_theme"
colnames(themes_df)[colnames(themes_df) == "id"] <- "sub_theme_id"
colnames(themes_df)[colnames(themes_df) == "parent_id"] <- "theme_id"
colnames(sets_df)[colnames(sets_df) == "name"] <- "set_name"
colnames(inventoryparts_df)[colnames(inventoryparts_df) == "quantity"] <- "inventorypart_quantity"
colnames(inventorysets_df)[colnames(inventorysets_df) == "quantity"] <- "inventorysets_quantity"
colnames(prices_df)[colnames(prices_df) == "Theme"] <- "theme_name"
colnames(prices_df)[colnames(prices_df) == "Subtheme"] <- "sub_theme"
colnames(prices_df)[colnames(prices_df) == "Pieces"] <- "num_parts"
colnames(prices_df)[colnames(prices_df) == "Name"] <- "set_name"
colnames(prices_df)[colnames(prices_df) == "Year"] <- "year"
colnames(sets_df)[colnames(sets_df) == "theme_id"] <- "sub_theme_id"

## dropping columns from prices that are unnecessary
prices_df <- subset(prices_df, select=-c(UKPrice,CAPrice, EUPrice, ImageURL, OwnedBy, WantedBy, Variant, SetID, Minifigs, Number))
sum(is.na(prices_df$num_parts))
#[1] 3070

# determine if we have enough data to drop any sets without prices
nrow(prices_df) - sum(is.na(prices_df$USPrice))
#[1] 7989
# drop price NAs
price_df <- prices_df[!(is.na(prices_df$USPrice)), ]
# Could drop piece NA  - takes down to 6000 obs - not sure if aligns with set data 
#price_df <- price_df[!(is.na(price_df$Pieces)), ]

# impute the theme ids for those theme_id = NA (will equal the subtheme)
themes_df$theme_id[is.na(themes_df$theme_id)] <- themes_df$sub_theme_id[is.na(themes_df$theme_id)]


# Merge all dataframes to master dataframe

# 1. Consider inventoryparts as the base dataset (Since it is the largest in size)
# Merge inventoryparts with colors on color_id <> id
master_df <- merge(x = inventoryparts_df, y = colors_df,by.x = "color_id", by.y = "id")

# 2. Merge parts and partcategories on part_cat_id <> id
parts_partcat_merge <- merge(x = parts_df, y = partcategories_df, by.x = "part_cat_id", by.y = "id")

# 3. Merge parts_partcat_merge with master on partnum
master_df <- merge(master_df, parts_partcat_merge, by = "part_num", all.x = TRUE)

# 4. Merge sets and themes on theme_id <> id
sets_themes_merge <- merge(x = sets_df, y = themes_df, by.x = "sub_theme_id", by.y = "sub_theme_id")

# 5. Merge set_themes_merge with the prices dta on set_name, year

set_themes_merge2 <- merge(sets_themes_merge, price_df, by=c('set_name', 'year'))
#part numbers were close to not identical, dropping the second column that was created, ditto with the subtheme
set_themes_merge2 <- subset(set_themes_merge2, select=-c(num_parts.y, sub_theme.y))
# rename the columns that got changed
colnames(set_themes_merge2 )[colnames(set_themes_merge2 ) == "num_parts.x"] <- "num_parts"
colnames(set_themes_merge2 )[colnames(set_themes_merge2 ) == "sub_theme.y"] <- "sub_theme"

# 6. Merge inventories with inventorysets on (id, set_num)<>(inventory_id, set_num)
inventories_invset_merge <- merge(x = inventories_df, y = inventorysets_df, by.x = c("id","set_num"), by.y = c("inventory_id","set_num"), all = TRUE)

# 7. Merge inventory sets with inventories_st_merge on set_num
inventorysets_settheme_merge <- merge(inventories_invset_merge, set_themes_merge2, by = "set_num")

# 8. Merge master with inventories_st_merge on inventory_id <> id
master_df2 <- merge(x = master_df, y = inventorysets_settheme_merge, by.x = "inventory_id", by.y = "id", all = T)

# 9. Master with no set_num NAs
master_df_final <- master_df2[!(is.na(master_df2$set_num)), ]

dim(master_df_final)   #[1] 357281     22
str(master_df_final)

#
master_df_final$inventory_id <- as.factor(master_df_final$inventory_id)
master_df_final$color_id <- as.factor(master_df_final$color_id)
master_df_final$color_name <- as.factor(master_df_final$color_name)
master_df_final$rgb <- as.factor(master_df_final$rgb)
master_df_final$is_spare <- as.factor(master_df_final$is_spare)
master_df_final$is_trans <- as.factor(master_df_final$is_trans)
master_df_final$part_name <- as.factor(master_df_final$part_name)
master_df_final$part_cat_id <- as.factor(master_df_final$part_cat_id)
master_df_final$partcat_name <- as.factor(master_df_final$partcat_name)
master_df_final$set_num <- as.factor(master_df_final$set_num)
master_df_final$set_name <- as.factor(master_df_final$set_name)
master_df_final$version <- as.factor(master_df_final$version)
master_df_final$sub_theme_id <- as.factor(master_df_final$sub_theme_id)
master_df_final$sub_theme.x <- as.factor(master_df_final$sub_theme.x)
master_df_final$theme_id <- as.factor(master_df_final$theme_id)
master_df_final$theme_name <- as.factor(master_df_final$theme_name)


master_df_final$num_parts <- as.factor(master_df_final$num_parts)
master_df_final$inventorypart_quantity <- as.numeric(master_df_final$inventorypart_quantity)
master_df_final$inventorysets_quantity <- as.numeric(master_df_final$inventorysets_quantity)
master_df_final$part_num <- as.factor(master_df_final$part_num)
master_df_final$year <- as.factor(master_df_final$year)
master_df_final$USPrice <- as.numeric(master_df_final$USPrice)

dim(master_df_final)
names(master_df_final)

###### 2. Data Partition and Data Cleaning  #############
set.seed(777)
sam <- sample(357281, 357281/2)
train <- master_df_final[sam, ]
test <- master_df_final[-sam, ]

# Data Cleaning
sum(is.na(train$year))
sum(is.na(train$USPrice))
sum(is.na(train$theme_name))
sum(is.na(train$sub_theme.x))
sum(is.na(train$version))
sum(is.na(train$is_trans))
sum(is.na(train$partcat_name))

train <- train[!is.na(train$version),]
train <- train[!is.na(train$is_trans),]
train <- train[!is.na(train$partcat_name),]

#Check factor levels in factor variables between test and train
str(test$theme_name)
str(test$sub_theme.x)
str(test$partcat_name)
str(test$is_trans)
str(test$version)
str(test$year)

str(train$theme_name)
str(train$sub_theme.x)
str(train$partcat_name)
str(train$is_trans)
str(train$version)
str(train$year)

train$USPrice <- as.numeric(train$USPrice)
test$USPrice <- as.numeric(test$USPrice)


#Cleaning Test data
sum(is.na(test$year))
sum(is.na(test$USPrice))
sum(is.na(test$theme_name))
sum(is.na(test$sub_theme.x))
sum(is.na(test$version))
sum(is.na(test$is_trans))
sum(is.na(test$partcat_name))

test <- test[!is.na(test$version),]
test <- test[!is.na(test$is_trans),]
test <- test[!is.na(test$partcat_name),]


##Remove new levels in theme_name between test and train
te1 <-unique(test$theme_name)
tr1<-unique(train$theme_name)

te1[!(te1 %in% tr1)]
tr1[!(te1 %in% tr1)]

dim(test)
test <- test[!test$theme_name=="Power Functions",]
test <- test[!test$theme_name=="Dinosaurs",]
train <- train[!train$theme_name=="Power Functions",]
train <- train[!train$theme_name=="Dinosaurs",]

#dim(test)
#dim(train)

#Remove new levels in sub_theme.x between test and train
se1 <-unique(test$sub_theme.x)
sr1<-unique(train$sub_theme.x)

se1[!(se1 %in% sr1)]
sr1[!(se1 %in% sr1)]

test <- test[!test$sub_theme.x=="Master Building Academy",]
test <- test[!test$sub_theme.x=="Minifig Pack",]
test <- test[!test$sub_theme.x=="The Lord of the Rings",]
train <- train[!train$sub_theme.x=="Master Building Academy",]
train <- train[!train$sub_theme.x=="Minifig Pack",]
train <- train[!train$sub_theme.x=="The Lord of the Rings",]

dim(test)
dim(train)

#Remove new levels in partcat_name between test and train
pe1 <-unique(test$partcat_name)
pr1<-unique(train$partcat_name)

pe1[!(pe1 %in% pr1)]
pr1[!(pe1 %in% pr1)]

dim(test)
dim(train)

#Remove new levels in year between test and train
ye1 <-unique(test$year)
yr1<-unique(train$year)

ye1[!(ye1 %in% yr1)]
yr1[!(ye1 %in% yr1)]

test <- test[!test$year=="1964",]
test <- test[!test$year=="1971",]
train <- train[!train$year=="1964",]
train <- train[!train$year=="1971",]

ye1 <-unique(test$year)
yr1<-unique(train$year)

ye1[!(ye1 %in% yr1)]
yr1[!(ye1 %in% yr1)]

dim(test)
dim(train)

#remove NAs in USPrice
sum(is.na(train$USPrice))
sum(is.na(test$USPrice))
#train <- train[!is.na(train$USPrice),]
summary(train$USPrice)
summary(test$USPrice)


###### 3. Variable Selection #############

library(leaps)

# s.null <- lm(USPrice~1, data=train)
# s.full <- lm(USPrice~ is_trans + partcat_name + theme_name + sub_theme.x + version + year, 
#              data = train)
# 
# Stepwise selection
# step(s.null, scope=list(lower=s.null, upper=s.full), direction="both")

     #I tried to do stepwise variable selection. But because there are too many factor variables 
     #and too many levels in each factor variable, it is hard to run.
     #So I decided to select variable in the following ways.


#Data Exploration and Variable Selection
train <- subset(train, train$USPrice < 350)
train0 <- train[!train$USPrice == 0,]

plot(train$USPrice ~ train$year)    #have high related positive relationship
plot(train$USPrice ~ train$is_trans) # maybe related, not much, negative
plot(train$USPrice ~ train$version)  #related 1, or 2, positive

plot(train$USPrice ~ train$theme_name) #related, top theme_name
plot(train$USPrice ~ train$sub_theme.x) #related, top sub_theme.x 
plot(train$USPrice ~ train$partcat_name) #maybe some, top partcat_name

plot(train$USPrice ~ train$is_spare)  #not related
plot(train$USPrice ~ train$rgb)       #no big association
plot(train$USPrice ~ train$color_name) #no big association


  ## Variable Selection:

    ## inventary_id, theme_id, part_cat_id, sub_theme_id, color_id are not good variables for modeling.
    ## part_num, part_name, set_num, set_num, and num_part have thousands levels, not good for modeling
    ## color_name, rgb, is_spares are not related much with USPrice.

    ## Therefore,
    ## 6 Variables: year, version, in_trans, theme_name, sub_theme.x, partcat_nam, 
    ## which have high association with USPrice, are selected as predictors for modeling.



###### 4. Fit Linear Regression Models #############

#1. Build linear model using year variable

pricey.lm <-lm(USPrice ~ year, data = train)
summary(pricey.lm) 
      # By year is significant. But Adjusted R-Squared is low, Adjusted R-squared:  0.03689.
      # This means that other important variables are necessary.


#2. Built linear regression model using the following 6 variables
price.lm <- lm(USPrice~ is_trans + partcat_name + theme_name + sub_theme.x + version + year, data = train)
summary(price.lm)

     # The 6 variables year, version, is_trans, partcat_name, theme_name, sub_theme.x are ALL significant!
     # Adjusted R squared increased a lot. Adjusted R-squared: 0.4353
     # There must be some other variables that related to USPrice, but are not included in this data set.


###### 4. Cross Validation: K=5 #############

library(boot)
set.seed(777)

#Check the full model
price.glm <- glm(USPrice~ is_trans + partcat_name + theme_name + sub_theme.x + version + year, data = train)
cv.error = cv.glm(train, price.glm, K=5)
attributes(cv.error)
cv.error$delta
   ## Problem with CV: 
   ## error message: prediction from a rank-deficient fit may be misleading
   ## Reasons: maybe because too many levels in each factor variables
   

#Check the USPrice~year Model
cv.error1 <- cv.glm(train, pricey.lm, K=5)
cv.error1$delta
   ## error message: prediction from a rank-deficient fit may be misleading
   ## Reasons: maybe because too many levels in each factor variables


#Calculate mean squared errro of the model
yhat <- fitted(price.lm)
mse <- mean(train$USPrice - yhat)^2
mse  
    ##[1] 2.814261e-31
  
  
###### 5. Check Model Accuracy  #############

# Normal Probability Plot

qqnorm(rstudent(price.lm))
qqline(rstudent(price.lm))
     ## The plot shows a rough linear pattern in general, 
     ## although several outliers at the left-end and some fat tail at right-upper end.


#Residual plot vs. fitted values
ti <- rstudent(price.lm)
yhat <- fitted(price.lm)
plot(yhat,ti)
abline(h=0)

     ## Plot shows balanced residual distribution.


###### 6. Transformation  ############# 

library(MASS)

#Remove the observatins of zero in USPrice, since boxcox asks for positive arguments
train0 <- train[!train$USPrice==0,]

#Fit the model again
price0.lm <- glm(USPrice~ is_trans + partcat_name + theme_name + sub_theme.x + version + year, data = train0)

out <- boxcox(price0.lm)
range(out$x[out$y > max(out$y)-qchisq(0.95,1)/2])
     ## alpha = 0.18
     ## Try log transfomation of y response

#Log transformation of response variable

summary(train0$USPrice) 
summary(log10(train0$USPrice))
summary(log2(train0$USPrice))

train0$USPrice_trans <- log(train0$USPrice +1)


#Run linear regression again
price0_trans.lm <- glm(USPrice_trans~ is_trans + partcat_name + theme_name + sub_theme.x + version + year, data = train0)

# Normal Probability Plot

qqnorm(rstudent(price0_trans.lm))
qqline(rstudent(price0_trans.lm))

      ## The plot shows a much better linear pattern in general.


#Residual plot vs. fitted values
ti <- rstudent(price0_trans.lm)
yhat <- fitted(price0_trans.lm)
plot(yhat,ti)
abline(h=0)

       ## The plot shows that the residuals have balanced distributed.


###### 7. Muticollinearity  ##############

# Multicollinearity checking needs to use numeric avariables, since the 6 variables in our model are all factors, 
# this doesn't apply here.
 


###### 8. Prediction of Test Data Set  ############# 

#Prediction of USPrice using year predictor variable
pred1 <- predict(pricey.lm, newdata = test)
length(pred1)

mse <- mean(test$USPrice - pred1)^2
mse
    #[1] 2.957607


#Prediction of USPrice using all 6 variables
pred <- predict(price.lm, newdata = test)
length(pred)

mse <- mean(test$USPrice - pred)^2
mse
    #[1] [1] 1.12291


#Prediction using log-tranformed model

#remove the new level in test
pred0 <- predict(price0_trans.lm, newdata = test)
length(pred0)
range(pred0)

yhat <- exp(pred0) -1
mse <- mean(test$USPrice - yhat)^2
mse
    #133.807

## Therefore, the best model is price.lm
   


###### 9. Summary of the Final Linear Regression Mode  ############# 

# Predictor variables: year, theme_name, sub_theme.x, version, partcat_name, is_trans
# Response variables: USPrice

# Final linear Regression Model:
price.lm <- glm(USPrice~ is_trans + partcat_name + theme_name + sub_theme.x + version + year, data = train)

#Prediction of USPrice using all 6 variables:
pred <- predict(price.lm, newdata = test)
length(pred)

mse <- mean(test$USPrice - pred)^2
mse  #[1] 1.12291 

#Test MSE is 1.12291
 
  

###### 10. ggplot to show the variable relationships with USPrice  ############# 

#1.Plot to show that Lego Price ("USPrice") increases with Years ("year")

#2.The top 10 Theme Names ("theme_name") with highest price ("USPrice")

#3.The top 10 SUb_Theme names ("sub_theme.x") with highest price ("USPrice")

#4.The top 10 Part Name ("partcat_name") with highest price ("USPrice")

#5.Plot of Lego Price ("USPrice") vs. Lego Version ("version"):  version 2 related to higher USPrice

#6.Plot of Lego Price ("USPrice") vs. In_Transparent ("in_trans") : transparency negatively related to USPrice




