/*
SPDX-License-Identifier: CC-BY-4.0
(c) Desenvolvido por Claudio Girao Barreto
This work is licensed under a Creative Commons Attribution 4.0 International License.
*/

pragma solidity 0.8.4;

/**
 * @dev Interface of the ERC20 standard as defined in the EIP.
 */
interface IERC20 {
    /**
     * @dev Returns the amount of tokens in existence.
     */
    function totalSupply() external view returns (uint256);

    /**
     * @dev Returns the amount of tokens owned by `account`.
     */
    function balanceOf(address account) external view returns (uint256);

    /**
     * @dev Moves `amount` tokens from the caller's account to `recipient`.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transfer(address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Returns the remaining number of tokens that `spender` will be
     * allowed to spend on behalf of `owner` through {transferFrom}. This is
     * zero by default.
     *
     * This value changes when {approve} or {transferFrom} are called.
     */
    function allowance(address owner, address spender) external view returns (uint256);

    /**
     * @dev Sets `amount` as the allowance of `spender` over the caller's tokens.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * IMPORTANT: Beware that changing an allowance with this method brings the risk
     * that someone may use both the old and the new allowance by unfortunate
     * transaction ordering. One possible solution to mitigate this race
     * condition is to first reduce the spender's allowance to 0 and set the
     * desired value afterwards:
     * https://github.com/ethereum/EIPs/issues/20#issuecomment-263524729
     *
     * Emits an {Approval} event.
     */
    function approve(address spender, uint256 amount) external returns (bool);

    /**
     * @dev Moves `amount` tokens from `sender` to `recipient` using the
     * allowance mechanism. `amount` is then deducted from the caller's
     * allowance.
     *
     * Returns a boolean value indicating whether the operation succeeded.
     *
     * Emits a {Transfer} event.
     */
    function transferFrom(address sender, address recipient, uint256 amount) external returns (bool);

    /**
     * @dev Emitted when `value` tokens are moved from one account (`from`) to
     * another (`to`).
     *
     * Note that `value` may be zero.
     */
    event Transfer(address indexed from, address indexed to, uint256 value);

    /**
     * @dev Emitted when the allowance of a `spender` for an `owner` is set by
     * a call to {approve}. `value` is the new allowance.
     */
    event Approval(address indexed owner, address indexed spender, uint256 value);
}



/// @title Manages the contract owner
contract Owned {
    address payable contractOwner;

    constructor() { 
        contractOwner = payable(msg.sender); 
    }
    
    function whoIsTheOwner() public view returns(address) {
        return contractOwner;
    }
}


/// @title Mortal allows the owner to kill the contract
contract Mortal is Owned  {
    function kill() public {
        require(msg.sender==contractOwner, "Only owner can destroy the contract");
        selfdestruct(contractOwner);
    }
}




/// @title ERC-20 Token template
/*
    Permite que sejam transferidos tokens representativos de descontos concedidos aos cientes como forma de fidelização.
    Não há casas decimais - cada token corresponde a um percentual fixo de desconto. ex. 2 tokens = 2% de desconto.
    Cada vez que o cliente comparece à loja, é-lhe transferido um certo número de tokens.
    Quando quiser utilizar os descontos, basta transferir de volta ao dono do contrato.
    O principal recurso é a possibilidade de armazenar Ether no contrato, de modo que os clientes
    não sejam obrigados a pagar pelo uso dos tokens quando forem resgatar os descontos. 
*/

contract Descontos is IERC20, Mortal {
    string private myName;
    string private mySymbol;
    uint256 private myTotalSupply;
    uint256 public decimals;
    uint256 public bonusCliente;  // valor de Ether (em wei) que será transferido aos clientes

    mapping (address=>uint256) balances;
    
    /*
        se o cliente recebeu uma doação antes e ainda não fez uso dos tokens de desconto,
        ele não deve receber doação novamente. Somente quando o seu saldo anterior de tokens estiver
        zerado é que ele vai receber nova doação (ou seja, não pode usar descontos parciais, embora
        possa acumular descontos). Não pode controlar pelo saldo de tokens, porque ele pode ter 
        transferido seus tokens para outra pessoa
        
    */
    
    mapping (address=>bool) recebeuDoacao;  
    
    mapping (address=>mapping (address=>uint256)) ownerAllowances;

    constructor() {
        myName = "Descontos";
        mySymbol = "DESC";
        decimals = 0;
        bonusCliente = 0.0000000408 ether;
        _mint(msg.sender, (1000000 * (10 ** decimals)));
    }

    function name() public view returns(string memory) {
        return myName;
    }

    function symbol() public view returns(string memory) {
        return mySymbol;
    }

    function totalSupply() public override view returns(uint256) {
        return myTotalSupply;
    }

    function balanceOf(address tokenOwner) public override view returns(uint256) {
        return balances[tokenOwner];
    }

    function allowance(address tokenOwner, address spender) public override view returns(uint256) {
        return ownerAllowances[tokenOwner][spender];
    }

    function transfer(address to, uint256 amount) public override  
                            hasEnoughBalance(msg.sender, amount, "Nao ha saldo de tokens") 
                            tokenAmountValid(amount)
                            temSaldoParaDoacao("Nao ha saldo no contrato para realizar a doacao para o cliente" ) 
                            returns(bool) {
                                
        balances[msg.sender] = balances[msg.sender] - amount;
        balances[to] = balances[to] + amount;
        
        
        /* 
        
            A doação de ETH ao cliente só ocorre quando os tokens de desconto são transferidos pelo dono do contrato
            e desde que o cliente já não tenha recebido uma doação de Eth.
        
        */
        
        if ((msg.sender == contractOwner) && (!recebeuDoacao[to])) {
            
                transferirDoacaoEth(to);
                recebeuDoacao[to] = true;
        }
        
   
        
         /* 
        
            A reativação da possibilidade de doação ao cliente ocorre:
            se ele está transferindo todos os seus tokens para o proprietário do contrato
        
     
        
        */
        
     
        
        if ((to == contractOwner) && (balances[msg.sender] == 0)) {
            recebeuDoacao[msg.sender]=false;
        }
        

            
        
        
        
        emit Transfer(msg.sender, to, amount);
        return true;
    } 

    function approve(address spender, uint limit) public override returns(bool) {
        ownerAllowances[msg.sender][spender] = limit;
        emit Approval(msg.sender, spender, limit);
        return true;
    }

    function transferFrom(address from, address to, uint256 amount) public override 
                                hasEnoughBalance(from, amount, "Nao ha saldo de tokens") 
                                isAllowed(msg.sender, from, amount) 
                                tokenAmountValid(amount)
                                                        returns(bool) {
                                                            
        balances[from] = balances[from] - amount;
        balances[to] += amount;
        ownerAllowances[from][msg.sender] = amount;
        emit Transfer(from, to, amount);
        return true;
    }
    
    function _mint(address account, uint256 amount) internal virtual {
        require(account != address(0), "ERC20: mint to the zero address");

        myTotalSupply = myTotalSupply + amount;
        balances[account] = balances[account] + amount;
        emit Transfer(address(0), account, amount);
    }
    


    modifier hasEnoughBalance(address owner, uint amount, string memory _erro) {
        uint balance;
        balance = balances[owner];
        require (balance >= amount, _erro); 
        _;
    }

    modifier isAllowed(address spender, address tokenOwner, uint amount) {
        require (amount <= ownerAllowances[tokenOwner][spender]);
        _;
    }

    modifier tokenAmountValid(uint256 amount) {
        require(amount > 0);
        require(amount <= myTotalSupply);
        _;
    }
    
    modifier onlyOwner(string memory _erro) {
        require(msg.sender==contractOwner, _erro);
        _;
    }
    
    /*
        Funções de gestão do saldo em Ether do contrato
    */
    
    function consultarSaldoEthContrato() view public onlyOwner("Apenas o proprietario pode consultar o saldo do contrato") returns (uint256) {
        
        return address(this).balance;
        
    }
    
    function recarregarSaldoEthContrato() payable public onlyOwner("Apenas o proprietario pode recarregar contrato") {
        
        
    }

    function resgatarSaldoEthContrato(uint256 _resgate) public onlyOwner("Apenas o proprietario pode resgatar o saldo do contrato") {
        require(_resgate <= address(this).balance, "O resgate extrapola o valor armazenado no contrato");
        contractOwner.transfer(_resgate);
        
    }
    
    function definirValorDoacaoEth(uint256 _bonus) public onlyOwner("Apenas o proprietario pode definir o bonus que sera dado ao cliente") {
        
        bonusCliente = _bonus;
    }
    
    function transferirDoacaoEth(address _cliente) public 
                onlyOwner("Apenas o proprietario pode fazer doacoes ao clientes") 
                temSaldoParaDoacao("Nao ha saldo no contrato para realizar a doacao para o cliente" ) {
                    
        address payable _clientePagavel = payable (_cliente);
        _clientePagavel.transfer(bonusCliente);
        
    }
    
    modifier temSaldoParaDoacao(string memory _erro) {
        require(bonusCliente <= address(this).balance, _erro);
        _;
    }
    

}
