import yaml

drive_file = file('drives.yml','r')
loaded_file = yaml.load(drive_file)

try:
    if(loaded_file['drives']['hdd'] is not None):
        print("lvm_volumes:")
        for drive in loaded_file['drives']['hdd']:
            print('  - data: ' + loaded_file['drives']['hdd'][drive]['name'])
            print('    data_vg: ' + loaded_file['drives']['hdd'][drive]['name'])
            print('    wal: ' + loaded_file['drives']['hdd'][drive]['wal_lv'])
            print('    wal_vg: ' + loaded_file['drives']['hdd'][drive]['wal_vg'])
            print('    db: ' + loaded_file['drives']['hdd'][drive]['db_lv'])
            print('    db_vg: ' + loaded_file['drives']['hdd'][drive]['db_vg'])
except TypeError:
    print("Error in drives.yml")
    exit(1)
except KeyError:
    try:
        if(loaded_file['drives']['ssd'] is not None):
            print("lvm_volumes:")
            for drive in loaded_file['drives']['ssd']:
                print('  - data: ' + loaded_file['drives']['ssd'][drive]['name'])
                print('    data_vg: ' + loaded_file['drives']['ssd'][drive]['name'])
                print('    wal: ' + loaded_file['drives']['ssd'][drive]['wal_lv'])
                print('    wal_vg: ' + loaded_file['drives']['ssd'][drive]['name'])
                print('    db: ' + loaded_file['drives']['ssd'][drive]['db_lv'])
                print('    db_vg: ' + loaded_file['drives']['ssd'][drive]['name'])
    except KeyError:
        print("Error in drives.yml")
        exit(1)
    except TypeError:
        print("Error in drives.yml")
        exit(1)
exit(0)
