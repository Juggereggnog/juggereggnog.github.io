library(tidyverse)
library(usmap)
library(statebins)
library(geofacet)
library(lubridate)
library(egg)

popvote <- read_csv("data/narrative/popvote_1948-2020.csv") %>% 
  mutate(pv = ifelse(year == 2020, pv * 100, pv),
         pv2p = ifelse(year == 2020, pv2p * 100, pv2p),
         pv_win = ifelse(pv2p > 50.0, TRUE, FALSE))

pvstate <- read_csv("data/narrative/popvote_bystate_1948-2020.csv") %>% 
  arrange(state, year) %>% 
  mutate(D_pv2p = ifelse(year == 2020, D_pv2p * 100, D_pv2p),
         R_pv2p = ifelse(year == 2020, R_pv2p * 100, R_pv2p),
         win_margin = D_pv2p - R_pv2p,
         state_win = case_when(win_margin > 0 ~ "win",
                               win_margin < 0 ~ "lose",
                               TRUE ~ "tie")) %>% 
  filter(state != "District of Columbia") %>% 
  group_by(state) %>% 
  mutate(prev_win = lag(state_win, n = 1),
         same = ifelse(state_win == prev_win, "same", "diff")) %>% 
  select(state, year, everything())

econ <- read_csv("data/narrative/econ.csv") %>% 
  filter(year >= 1948)

covid <- read_csv("data/narrative/case_daily_trends__united_states.csv", skip = 3) %>% 
  mutate(date = mdy(Date),
         new_cases = `New Cases`,
         roll_avg = `7-Day Moving Avg`) %>% 
  select(date:roll_avg)

pollavg <- read_csv("data/narrative/pollavg_1948-2020.csv")

pollstate <- read_csv("data/narrative/pollavg_bystate_1968-2016.csv")

vep <- read_csv("data/narrative/vep_1980-2016.csv") %>% 
  arrange(year)

vep <- vep %>% 
  filter(year %% 4 == 0) %>% 
  group_by(state) %>% 
  mutate(prev_vep = lag(VEP, n = 1),
         vep_margin = VEP - prev_vep) %>% 
  filter(year != 1980) %>% 
  summarize(year = year,
            state = state,
            VEP = VEP,
            avg_vep_margin = round(mean(vep_margin))) %>% 
  filter(year == 2016) %>% 
  mutate(VEP = VEP + avg_vep_margin, year = 2020) %>% 
  select(year, state, VEP) %>% 
  full_join(vep, by = c("year", "state", "VEP")) %>% 
  filter(!state %in% c("United States", "District of Columbia")) %>% 
  arrange(year, state) %>% 
  select(-VAP)

turnout <- read_csv("data/narrative/turnout_1980-2016.csv") %>% 
  mutate(turnout_pct = substr(turnout_pct, 1, nchar(turnout_pct) - 1),
         turnout_pct = as.double(turnout_pct),
         turnout_pct = ifelse(year == 2016, round(turnout_pct * 100, 1), turnout_pct)) %>% 
  filter(!is.na(turnout_pct),
         !state %in% c("District of Columbia", "United States"))

turnout <- turnout %>% 
  full_join(vep, by = c("year", "state", "VEP")) %>% 
  arrange(year, state) %>% 
  filter(year == 2020) %>% 
  mutate(turnout = pvstate$total[pvstate$year == 2020],
         turnout_pct = round(100 * turnout / VEP, 1)) %>% 
  full_join(turnout) %>% 
  arrange(year, state) %>% 
  select(-VAP)

poll_pvstate_vep <- pvstate %>% 
  inner_join(pollstate %>% 
               filter(weeks_left <= 5, days_left >= 3, state != "District of Columbia") %>%
               group_by(state, year, candidate_name) %>%
               top_n(1, poll_date)) %>% 
  mutate(D_pv = (D / total) * 100,
         R_pv = (R / total) * 100) %>% 
  inner_join(vep)


# Making (relevant) polls_2020 dataframe (polls 2 days out)
pollstate_2020 <- data.frame(ID = 1:100)
pollstate_2020$state <- state.name
pollstate_2020 <- pollstate_2020 %>% 
  arrange(state) %>% 
  select(-ID)
pollstate_2020$party <- c("democrat", "republican")
## Manually coded in FiveThirtyEight state poll avgs alphabetically (two per state)
pollstate_2020$avg_poll <- c(38.2, 57.0, 43.4, 51.0, 48.7, 45.3, 35.9, 59.1,
                             61.4, 33.4, 54.6, 40.6, 57.4, 32.5, 58.7, 34.9,
                             48.5, 46.6, 48.4, 46.8, 63.6, 30.7, 37.7, 57.5,
                             55.0, 40.9, 41.8, 51.1, 45.6, 47.3, 41.7, 51.7,
                             39.5, 55.6, 37.0, 57.4, 53.5, 39.9, 61.6, 31.9,
                             65.9, 29.2, 51.2, 42.8, 51.2, 42.3, 39.2, 55.6,
                             44.2, 50.9, 45.3, 50.2, 42.4, 52.4, 49.5, 44.4,
                             53.8, 42.8, 59.6, 37.2, 53.7, 42.2, 62.8, 32.1,
                             49.0, 46.7, 38.1, 56.6, 46.9, 47.1, 36.3, 58.9,
                             57.9, 38.0, 49.9, 45.0, 63.4, 32.3, 43.6, 51.4,
                             39.2, 53.8, 41.3, 54.4, 47.0, 48.4, 41.6, 52.2,
                             65.6, 28.7, 53.2, 41.9, 58.5, 35.5, 34.0, 61.3,
                             51.9, 43.7, 30.5, 62.6)

pollstate_2020 <- pollstate_2020 %>% 
  pivot_wider(names_from = party, values_from = avg_poll) %>% 
  mutate(win_margin = democrat - republican,
         # Alternate reality where Trump had 2.5% uniform swing in poll averages
         shift_d = democrat - 2.5,
         shift_r = republican + 2.5)



######################### DESCRIPTIVE ANALYSIS #################################

# Checking correlation between polling average and rolling average
poll_covid <- pollavg %>% 
  filter(year == 2020) %>% 
  inner_join(covid, by = c("poll_date" = "date"))

# Biden pv NOT overestimated (+0.005), Trump underestimated (-0.0338)
p1 <- poll_covid %>% 
  filter(party == "republican") %>% 
  ggplot(aes(x = poll_date, y = avg_support)) +
  geom_line(color = "red", alpha = 0.6, size = 1.5) +
  geom_smooth(method = "lm") +
  labs(x = "Date of Poll",
      y = "Average Support") +
  theme_bw()

p2 <- poll_covid %>% 
  filter(party == "republican") %>% 
  ggplot(aes(x = poll_date)) +
  geom_col(aes(y = new_cases), fill = "darkblue", alpha = 0.65) +
  geom_line(aes(y = roll_avg), color = "red", alpha = 0.6, size = 2) +
  geom_smooth(aes(y = roll_avg), method = "lm") +
  labs(x = "Date",
       y = "# of New Cases") +
  theme_bw()

# Negative Correlation!
p3 <- ggarrange(p1, p2, ncol = 1)

ggsave("polls_n_pandemics.png", plot = p3, path = "figures/narrative", height = 4, width = 8)


# Weak correlations (< 0.12) belie apparent visual inverse relationship
cor(poll_covid$avg_support[month(poll_covid$poll_date) <= 7], poll_covid$roll_avg[month(poll_covid$poll_date) <= 7])
cor(poll_covid$avg_support[month(poll_covid$poll_date) %in% 7:9], poll_covid$roll_avg[month(poll_covid$poll_date) %in% 7:9])
cor(poll_covid$avg_support[month(poll_covid$poll_date) <= 7], poll_covid$new_cases[month(poll_covid$poll_date) <= 7])
cor(poll_covid$avg_support[month(poll_covid$poll_date) %in% 7:9], poll_covid$new_cases[month(poll_covid$poll_date) %in% 7:9])


# Joining polling data with economic data, running new regression
mlk <- pollavg %>% 
  mutate(quarter = case_when(month(poll_date) %in% 1:3 ~ 1,
                             month(poll_date) %in% 4:6 ~ 2,
                             month(poll_date) %in% 7:9 ~ 3,
                             month(poll_date) %in% 10:12 ~ 4,)) %>% 
  group_by(year, quarter, candidate_name, party) %>% 
  summarize(avg_support = mean(avg_support)) %>% 
  ungroup() %>% 
  left_join(econ, by = c("year", "quarter")) %>% 
  left_join(popvote, by = c("year", "party")) %>% 
  select(-candidate, -(inflation:stock_volume)) %>% 
  filter(incumbent_party == TRUE, year != 2020, quarter == 2)

lm_polls_econ <- lm(pv2p ~ avg_support + GDP_growth_qt, data = mlk)
summary(lm_polls_econ)

# Poll Support: low: 41.08826, Q2: 43.02516, Q3: 42.30202, Avg Q2+Q3: 46.30655
# GDP Growth: Avg Q2+Q3: -0.7424405
gdp_new <- data.frame(avg_support = 43.02516,
                      GDP_growth_qt = -0.7424405)

predict(lm_polls_econ, gdp_new, interval = "prediction")



######################## PREDICTIVE ANALYSIS ###################################

s <- unique(poll_pvstate_vep$state)

pollR_sd <- sd(pollstate_2020$republican) / 100

pollD_sd <- sd(pollstate_2020$democrat) / 100


# Running binomial logit regression for each state
meow <- lapply(s, function(s){
  
  VEP_s_2020 <- as.integer(vep$VEP[vep$state == s & vep$year == 2016])
  
  poll_s_R_2020 <- pollstate_2020$republican[pollstate_2020$state == s]
  poll_s_D_2020 <- pollstate_2020$democrat[pollstate_2020$state == s]
  
  s_R <- poll_pvstate_vep %>% filter(state == s, party == "republican")
  s_D <- poll_pvstate_vep %>% filter(state == s, party == "democrat")
  
  ## Fit D and R models
  s_R_glm <- glm(cbind(R, VEP-R) ~ avg_poll, s_R, family = binomial)
  s_D_glm <- glm(cbind(D, VEP-D) ~ avg_poll, s_D, family = binomial)
  
  ## Get predicted draw probabilities for D and R
  prob_Rvote_s_2020 <- predict(s_R_glm, newdata = data.frame(avg_poll = poll_s_R_2020), type = "response")[[1]]
  prob_Dvote_s_2020 <- predict(s_D_glm, newdata = data.frame(avg_poll = poll_s_D_2020), type = "response")[[1]]
  
  ## Get predicted distribution of draws from the population
  avg_turnout_s <- turnout %>% 
    filter(state == s, !is.na(turnout_pct)) %>% 
    summarize(avg_turnout = mean(turnout_pct) / 100) %>% 
    pull(avg_turnout)
  
  sd_turnout_s <- turnout %>% 
    filter(state == s, !is.na(turnout_pct)) %>% 
    summarize(sd_turnout = sd(turnout_pct) / 100) %>% 
    pull(sd_turnout)
  
  ## Creating turnout distribution (LVP = Likely Voter Population)
  LVP_s_2020 <- rnorm(10000, mean = VEP_s_2020 * avg_turnout_s, sd = VEP_s_2020 * sd_turnout_s)
  
  normalR <- rnorm(10000, mean = prob_Rvote_s_2020, sd = pollR_sd)
  normalD <- rnorm(10000, mean = prob_Dvote_s_2020, sd = pollD_sd)
  
  sim_Rvotes_s_2020 <- rbinom(n = 10000, size = round(LVP_s_2020), prob = normalR)
  sim_Dvotes_s_2020 <- rbinom(n = 10000, size = round(LVP_s_2020), prob = normalD)
  
  ## Simulating a distribution of election results: Biden win margin
  sim_elxns_s_2020 <- ((sim_Dvotes_s_2020 - sim_Rvotes_s_2020) / (sim_Dvotes_s_2020 + sim_Rvotes_s_2020)) * 100
  
  
  cbind.data.frame(election_id = 1:10000,
                   state = s,
                   prob_Rvote_s_2020,
                   prob_Dvote_s_2020,
                   VEP_s_2020,
                   LVP_s_2020,
                   normalR,
                   normalD,
                   sim_Rvotes_s_2020,
                   sim_Dvotes_s_2020,
                   sim_elxns_s_2020)
})

dooby <- do.call(rbind, meow)


# DC not included, but auto-awarded to Biden (+3 EV)
dooby <- dooby %>% 
  filter(!is.na(sim_elxns_s_2020)) %>% 
  mutate(state_win = case_when(sim_elxns_s_2020 > 0 ~ "win",
                               sim_elxns_s_2020 < 0 ~ "lose",
                               TRUE ~ "tie"),
         state_abb = state.abb[match(state, state.name)],
         ev = case_when(state_abb == "AL" ~ 9,
                        state_abb == "AK" ~ 3,
                        state_abb == "AZ" ~ 11,
                        state_abb == "AR" ~ 6,
                        state_abb == "CA" ~ 55,
                        state_abb == "CO" ~ 9,
                        state_abb == "CT" ~ 7,
                        state_abb == "DE" ~ 3,
                        state_abb == "FL" ~ 29,
                        state_abb == "GA" ~ 16,
                        state_abb == "HI" ~ 4,
                        state_abb == "ID" ~ 4,
                        state_abb == "IL" ~ 20,
                        state_abb == "IN" ~ 11,
                        state_abb == "IA" ~ 6,
                        state_abb == "KS" ~ 6,
                        state_abb == "KY" ~ 8,
                        state_abb == "LA" ~ 8,
                        state_abb == "ME" ~ 4,
                        state_abb == "MD" ~ 10,
                        state_abb == "MA" ~ 11,
                        state_abb == "MI" ~ 16,
                        state_abb == "MN" ~ 10,
                        state_abb == "MS" ~ 6,
                        state_abb == "MO" ~ 10,
                        state_abb == "MT" ~ 3,
                        state_abb == "NE" ~ 5,
                        state_abb == "NV" ~ 6,
                        state_abb == "NH" ~ 4,
                        state_abb == "NJ" ~ 14,
                        state_abb == "NM" ~ 5,
                        state_abb == "NY" ~ 29,
                        state_abb == "NC" ~ 15,
                        state_abb == "ND" ~ 3,
                        state_abb == "OH" ~ 18,
                        state_abb == "OK" ~ 7,
                        state_abb == "OR" ~ 7,
                        state_abb == "PA" ~ 20,
                        state_abb == "RI" ~ 4,
                        state_abb == "SC" ~ 9,
                        state_abb == "SD" ~ 3,
                        state_abb == "TN" ~ 11,
                        state_abb == "TX" ~ 38,
                        state_abb == "UT" ~ 6,
                        state_abb == "VA" ~ 13,
                        state_abb == "VT" ~ 3,
                        state_abb == "WA" ~ 12,
                        state_abb == "WV" ~ 5,
                        state_abb == "WI" ~ 10,
                        state_abb == "WY" ~ 3,
                        TRUE ~ 999),
         ev_won = ifelse(state_win == "win", ev, 0),
         ev_lost = ifelse(state_win == "win", 0, ev))


# Gathering win statistics for each state
dooby_wins <- dooby %>% 
  group_by(state) %>% 
  count(state_win) %>% 
  pivot_wider(names_from = state_win,
              values_from = n) %>% 
  mutate(win_prob = win / (win + lose) * 100)


# Same process as dooby but with the average win margin for each state
dooby_avgs <- dooby %>% 
  group_by(state) %>% 
  summarize(avg_Rvotes = mean(sim_Rvotes_s_2020),
            avg_Dvotes = mean(sim_Dvotes_s_2020)) %>% 
  mutate(avg_total_votes = avg_Rvotes + avg_Dvotes,
         avg_D_pv2p = avg_Dvotes / avg_total_votes * 100,
         avg_R_pv2p = avg_Rvotes / avg_total_votes * 100,
         avg_win_margin = avg_D_pv2p - avg_R_pv2p,
         avg_state_win = case_when(avg_win_margin > 0 ~ "win",
                                   avg_win_margin < 0 ~ "lose",
                                   TRUE ~ "tie"),
         state_abb = state.abb[match(state, state.name)],
         ev = case_when(state_abb == "AL" ~ 9,
                        state_abb == "AK" ~ 3,
                        state_abb == "AZ" ~ 11,
                        state_abb == "AR" ~ 6,
                        state_abb == "CA" ~ 55,
                        state_abb == "CO" ~ 9,
                        state_abb == "CT" ~ 7,
                        state_abb == "DE" ~ 3,
                        state_abb == "FL" ~ 29,
                        state_abb == "GA" ~ 16,
                        state_abb == "HI" ~ 4,
                        state_abb == "ID" ~ 4,
                        state_abb == "IL" ~ 20,
                        state_abb == "IN" ~ 11,
                        state_abb == "IA" ~ 6,
                        state_abb == "KS" ~ 6,
                        state_abb == "KY" ~ 8,
                        state_abb == "LA" ~ 8,
                        state_abb == "ME" ~ 4,
                        state_abb == "MD" ~ 10,
                        state_abb == "MA" ~ 11,
                        state_abb == "MI" ~ 16,
                        state_abb == "MN" ~ 10,
                        state_abb == "MS" ~ 6,
                        state_abb == "MO" ~ 10,
                        state_abb == "MT" ~ 3,
                        state_abb == "NE" ~ 5,
                        state_abb == "NV" ~ 6,
                        state_abb == "NH" ~ 4,
                        state_abb == "NJ" ~ 14,
                        state_abb == "NM" ~ 5,
                        state_abb == "NY" ~ 29,
                        state_abb == "NC" ~ 15,
                        state_abb == "ND" ~ 3,
                        state_abb == "OH" ~ 18,
                        state_abb == "OK" ~ 7,
                        state_abb == "OR" ~ 7,
                        state_abb == "PA" ~ 20,
                        state_abb == "RI" ~ 4,
                        state_abb == "SC" ~ 9,
                        state_abb == "SD" ~ 3,
                        state_abb == "TN" ~ 11,
                        state_abb == "TX" ~ 38,
                        state_abb == "UT" ~ 6,
                        state_abb == "VA" ~ 13,
                        state_abb == "VT" ~ 3,
                        state_abb == "WA" ~ 12,
                        state_abb == "WV" ~ 5,
                        state_abb == "WI" ~ 10,
                        state_abb == "WY" ~ 3),
         ev_won = ifelse(avg_state_win == "win", ev, 0),
         ev_lost = ifelse(avg_state_win == "win", 0, ev)) %>% 
  full_join(pvstate %>% filter(year == 2020), by = "state") %>% 
  filter(state != "District of Columbia") %>% 
  full_join(dooby_wins, by = "state") %>% 
  select(state, state_abb, avg_total_votes, avg_Dvotes, avg_Rvotes,
         avg_D_pv2p, avg_R_pv2p, avg_win_margin, avg_state_win, ev:ev_lost, win,
         lose, win_prob, total:state_win) %>% 
  mutate(bin_avg_state_win = ifelse(avg_state_win == "win", 1, 0),
         bin_state_win = ifelse(state_win == "win", 1, 0))


### Category Error? (Turnout too low)
### pred_R_pv2p: 45.57%, pred_D_pv2p: 54.43%
### actual_R_pv2p: 47.73%, actual_D_pv2p: 52.27%
sum(dooby_avgs$avg_Rvotes) / sum(dooby_avgs$avg_total_votes) * 100
sum(dooby_avgs$avg_Dvotes) / sum(dooby_avgs$avg_total_votes) * 100


### pred_R: 188, pred_D: 347 (+3 from D.C. = 350)
### actual_R: 232, actual_D: 303 (+3 from D.C. = 306)
sum(dooby_avgs$ev)
sum(dooby_avgs$ev_won)
sum(dooby_avgs$ev_lost)
