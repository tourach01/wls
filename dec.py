# decrypt_password.py
from weblogic.security.internal import SerializedSystemIni
from weblogic.security.internal.encryption import ClearOrEncryptedService
import sys

domain_home = sys.argv[1]
encrypted_pass = sys.argv[2]

encryption_service = SerializedSystemIni.getEncryptionService(domain_home)
ces = ClearOrEncryptedService(encryption_service)

clear_pass = ces.decrypt(encrypted_pass)
print(clear_pass)
