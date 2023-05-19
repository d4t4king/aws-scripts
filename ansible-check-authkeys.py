
import yaml
import pprint


STOREFILE = '/root/root_auth_keys.dat'


def get_line_count():
  afile = '/root/.ssh/authorized_keys'
  count = len(open(afile).readlines( ))
  return count


def read_dat():
  with open(STOREFILE, 'r') as stream:
    try:
      print(yaml.safe_load(stream))
    #except FileNotFoundError as fnferr:
      # write out the file (?)
    except yaml.YAMLError as exc:
      print(exc)


def write_dat(yamldict):
  with open(STOREFILE, 'w') as out:
    documents = yaml.dump(yamldict, STOREFILE)


def main():
  pp = pprint.PrettyPrinter(indent=4)
  stored = read_dat()
  cnt = get_line_count()
  print("Current count is " + str(cnt))  

if __name__=='__main__':
  main()

