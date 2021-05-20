// SPDX-License-Identifier: NONE

pragma solidity 0.8.4;

 // Permite consultar a subseção competente após ser informado o município onde reside a parte autora
 
contract ConsultaSubsecaoMunicipio {

    // mapeamento de município para subseção
    mapping (string => string) public competencias; 

    

    // permite vincular no mapping o município à subseção
    function incluirMunicipioEmSubsecao(string memory _municipio, string memory _subsecao) public {
        competencias[_municipio] = _subsecao;

    }
    
    // consultar a subseção a que se vincula o município
    function consultarSubsecaoDoMunicipio(string memory _municipio) public view returns (string memory){
        return competencias[_municipio];
    }
    


}
