import yaml
import sys

with open(sys.argv[1]) as file:
    data = yaml.load(file)
    print(data)
