require 'openssl'
require 'digest/sha1'

# Contract: define crypt_key
module AESCrypter
  def encrypt_to(str, filename)
    c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
    c.encrypt
    c.key = key = Digest::SHA1.hexdigest(crypt_key)
    c.iv = iv = c.random_iv
    e = c.update(str) + c.final
    File.open(filename, 'w') do |file|
      file.write(iv)
      file.write("\0")
      file.write(e)
    end
  end

  def decrypt_from(filename)
    contents = File.read(filename)
    iv = contents[0..16]
    e = contents[17..-1]
    d = nil

    if e != nil
      c = OpenSSL::Cipher::Cipher.new("aes-256-cbc")
      c.decrypt
      c.key = Digest::SHA1.hexdigest(crypt_key)
      c.iv = iv
      d = c.update(e) + c.final
    end
  end

  # Decrypts a block of data (encrypted_data) given an encryption key
  # and an initialization vector (iv).  Keys, iv's, and the data
  # returned are all binary strings.  Cipher_type should be
  # "AES-256-CBC", "AES-256-ECB", or any of the cipher types
  # supported by OpenSSL.  Pass nil for the iv if the encryption type
  # doesn't use iv's (like ECB).
  #:return: => String
  #:arg: encrypted_data => String
  #:arg: key => String
  #:arg: iv => String
  #:arg: cipher_type => String
  def decrypt(encrypted_data, key, iv, cipher_type)
    aes = OpenSSL::Cipher::Cipher.new(cipher_type)
    aes.decrypt
    aes.key = key
    aes.iv = iv if iv != nil
    aes.update(encrypted_data) + aes.final
  end

  # Encrypts a block of data given an encryption key and an
  # initialization vector (iv).  Keys, iv's, and the data returned
  # are all binary strings.  Cipher_type should be "AES-256-CBC",
  # "AES-256-ECB", or any of the cipher types supported by OpenSSL.
  # Pass nil for the iv if the encryption type doesn't use iv's (like
  # ECB).
  #:return: => String
  #:arg: data => String
  #:arg: key => String
  #:arg: iv => String
  #:arg: cipher_type => String
  def encrypt(data, key, iv, cipher_type)
    aes = OpenSSL::Cipher::Cipher.new(cipher_type)
    aes.encrypt
    aes.key = key
    aes.iv = iv if iv != nil
    aes.update(data) + aes.final
  end
end