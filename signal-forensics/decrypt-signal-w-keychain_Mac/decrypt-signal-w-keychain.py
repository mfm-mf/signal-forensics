#!/usr/bin/env python3
import os
import json
import argparse
from Crypto.Protocol.KDF import PBKDF2
from Crypto.Hash import SHA1
from Crypto.Cipher import AES
from Crypto.Util.Padding import unpad

def aes_decrypt_cbc(key, iv, data):
    cipher = AES.new(key, AES.MODE_CBC, iv)
    return cipher.decrypt(data)

def decrypt_signal_config(config_path, password_file, output_file=None):
    # Default values
    prefix = b'v10'
    salt = b'saltysalt'
    derived_key_len = 128 // 8
    num_iterations = 1003
    iv = b' ' * 16

    # Read password from file
    with open(password_file, 'r') as f:
        password = f.read().strip()

    # Read config file
    with open(os.path.expanduser(config_path), 'r') as f:
        config = json.loads(f.read())

    encrypted_key = bytes.fromhex(config['encryptedKey'])
    assert encrypted_key.startswith(prefix)
    encrypted_key = encrypted_key[len(prefix):]

    kek = PBKDF2(password, salt, dkLen=derived_key_len, count=num_iterations, hmac_hash_module=SHA1)
    decrypted_key = unpad(aes_decrypt_cbc(kek, iv, encrypted_key), block_size=16).decode('ascii')

    # Print to screen
    print(decrypted_key)

    # Optionally write to output file
    if output_file:
        with open(os.path.expanduser(output_file), 'w') as f:
            f.write(decrypted_key)

def main():
    parser = argparse.ArgumentParser(description='Decrypt Signal configuration')
    parser.add_argument('-c', '--config', 
                        default='~/Library/Application Support/Signal/config.json', 
                        help='Path to Signal config.json file')
    parser.add_argument('-p', '--password', 
                        required=True, 
                        help='Path to file containing password')
    parser.add_argument('-o', '--output', 
                        help='Optional output file to save decrypted key')
    
    args = parser.parse_args()
    
    decrypt_signal_config(args.config, args.password, args.output)

if __name__ == '__main__':
    main()