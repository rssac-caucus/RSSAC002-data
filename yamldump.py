import yaml
import sys

with open(sys.argv[1]) as file:
    data = yaml.load(file, Loader=yaml.SafeLoader)
    print(data)
