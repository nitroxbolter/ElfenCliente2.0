Criptografia usando o comando 


 

Agora iremos modificar a cryptografia

Daqui pra frente, partindo da idéia de que você já sabe criptografarseu OTCv8

Vamos em \src\framework\util\crypt.cpp

 

Procure as funções:

  Ocultar conteúdo
void Crypt::bdecrypt(uint8_t* buffer, int len, uint64_t k) {
    uint32_t const key[4] = { (uint32_t)(k >> 32), (uint32_t)(k & 0xFFFFFFFF), 0xDEADDEAD, 0xB00BEEEF };
    .....
}

void Crypt::bencrypt(uint8_t* buffer, int len, uint64_t k) {
    uint32_t const key[4] = { (uint32_t)(k >> 32), (uint32_t)(k & 0xFFFFFFFF), 0xDEADDEAD, 0xB00BEEEF };
    ...
}




- Recomendo inicialmente criar uma cópia da pasta que ira encriptar, pois não é reversivo

- Copie o endereço da pasta onde estão os arquivos

- Abra o cmd e navegue até esta pasta utilizando o comando cd (link do endereço da pasta)
- utilize o comando otclient_dx.exe --encrypt

- Aguarde o sistema sinalizar que os arquivos foram encriptados 