# fauxhai_generator

Spin up systems in AWS and generate new Fauxhai dumps

## Installation

```
$ gem install fauxhai_generator
```

## Usage

- Run `aws configure` to make sure you have a properly formatted AWS config file
- Make sure config.yml is updated with all the AMIs you want to run
- From the fauxhai directory run fauxhai_generator KEY_PAIR_NAME PATH_TO_KEYPAIR
