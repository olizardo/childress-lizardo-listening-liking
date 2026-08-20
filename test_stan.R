library(cmdstanr)
file <- write_stan_file("
data {
  int<lower=0> N;
  array[N] int<lower=0,upper=1> y;
}
parameters {
  real<lower=0,upper=1> theta;
}
model {
  theta ~ beta(1,1);
  y ~ bernoulli(theta);
}
")
mod <- cmdstan_model(file)
fit <- mod$sample(data = list(N=10, y=c(0,1,0,0,0,0,0,0,1,1)), chains=1, iter_sampling=100)
print(fit)
