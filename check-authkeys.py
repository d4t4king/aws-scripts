
import yaml

def get_line_count():
  afile = '/root/.ssh/authorized_keys'
  count = len(open(afile).readlines( ))
  return count

def read_dat():
  with open('root_auth_keys.dat', 'r') as stream:
    try:
      print(yaml.safe_load(stream))
    except yaml.YAMLError as exc:
      print(exc)

def write_dat():
  pass

def main():
  cnt = get_line_count()
  print("Current count is " + cnt)  

if __name__=='__main__':
  main()

