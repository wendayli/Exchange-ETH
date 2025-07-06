// SPDX-License-Identifier: MIT
pragma solidity ^0.8.0;

//IERC20.sol: Interfaz estándar para interactuar con tokens ERC-20.
//SafeMath.sol: Librería que evita errores aritméticos como desbordamientos 

import "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import "@openzeppelin/contracts/utils/math/SafeMath.sol";

contract SimpleDEX {
    using SafeMath for uint256; // Aplica operaciones seguras a todas las variables

    IERC20 public tokenA;
    IERC20 public tokenB;

    uint256 public reserveA;
    uint256 public reserveB;

    address public owner; //usado para control de acceso



    // ============================
    // EVENTOS
    /*
    LiquidityAdded: Se emite cuando se añade liquidez.
    Swapped: Cuando alguno realiza un intercambio.
    LiquidityRemoved: Al retirar liquidez.
    */
    event LiquidityAdded(address indexed provider, uint256 amountA, uint256 amountB);
    event Swapped(address indexed user, address fromToken, uint256 amountIn, uint256 amountOut);
    event LiquidityRemoved(address indexed provider, uint256 amountA, uint256 amountB);



    // ============================
    // EVENTOS
    /*
    * Este modificador restringe el acceso. 
    * Si no es el dueño, la transacción falla con el mensaje.
    */
    modifier onlyOwner() {
        require(msg.sender == owner, "Only owner");
        _;
    }


    // ============================
    // CONSTRUCTOR
    
    /*
    * Los tokens con los que trabajará el DEX.
    * Asigna el msg.sender (quien despliega el contrato) como owner.
    */

    constructor(address _tokenA, address _tokenB) {
        tokenA = IERC20(_tokenA);
        tokenB = IERC20(_tokenB);
        owner = msg.sender; 
    }
    
    // ============================
    // FUNCIONES


    /*
    * Solo el owner puede llamar esta función (onlyOwner).
    * Verifica que las cantidades sean mayores a cero.
    * Transfiere los tokens del usuario al contrato.
    * Actualiza las reservas del pool.
    * Emite un evento de registro.
    */

function addLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
    require(amountA > 0 && amountB > 0, "Amounts must be > 0");

    // Verificar allowances antes de transferir
    require(tokenA.allowance(msg.sender, address(this)) >= amountA, "TokenA: insufficient allowance");
    require(tokenB.allowance(msg.sender, address(this)) >= amountB, "TokenB: insufficient allowance");

    // Ahora sí, transferimos los tokens
    tokenA.transferFrom(msg.sender, address(this), amountA);
    tokenB.transferFrom(msg.sender, address(this), amountB);

    reserveA += amountA;
    reserveB += amountB;

    emit LiquidityAdded(msg.sender, amountA, amountB);
}


    /*
    * Solo el owner puede retirar liquidez.
    * Verifica que haya suficiente liquidez disponible.
    * Reduce las reservas del pool.
    * Devuelve los tokens al owner.
    * Emite evento de registro.
    */
    function removeLiquidity(uint256 amountA, uint256 amountB) external onlyOwner {
        require(reserveA >= amountA && reserveB >= amountB, "Not enough liquidity");

        reserveA -= amountA;
        reserveB -= amountB;

        tokenA.transfer(msg.sender, amountA);
        tokenB.transfer(msg.sender, amountB);

        emit LiquidityRemoved(msg.sender, amountA, amountB);
    }


    /* Valida entrada y existencia de liquidez.
    * Calcula una comisión del 0.3% (fee).
    * Aplica la fórmula AMM (x+dx)(y-dy)=xy simplificada.
    * Verifica que el resultado sea significativo (amountBOut > 0).
    * Actualiza reservas y transfiere tokens.
    * Emite evento de intercambio.
    */
    function swapAforB(uint256 amountAIn) external returns (uint256 amountBOut) {
        require(amountAIn > 0, "Input must be > 0");
        require(reserveA > 0 && reserveB > 0, "No liquidity");

        uint256 fee = amountAIn * 3 / 1000;
        uint256 amountAWithFee = amountAIn - fee;

        amountBOut = (reserveB * amountAWithFee) / (reserveA + amountAWithFee);

        // Permitimos usar casi toda la reserva, pero dejamos al menos 1 unidad
        require(reserveB - amountBOut >= 1, "Reserve cannot drop to zero");

        reserveA += amountAIn;
        reserveB -= amountBOut;

        tokenA.transferFrom(msg.sender, address(this), amountAIn);
        tokenB.transfer(msg.sender, amountBOut);

        emit Swapped(msg.sender, address(tokenA), amountAIn, amountBOut);
    }

    /* 
    * Funciona igual que swapAforB, pero invirtiendo los roles de TokenA y TokenB. 
    */
    function swapBforA(uint256 amountBIn) external returns (uint256 amountAOut) {
        require(amountBIn > 0, "Input must be > 0");
        require(reserveA > 0 && reserveB > 0, "No liquidity");

        uint256 fee = amountBIn * 3 / 1000;
        uint256 amountBWithFee = amountBIn - fee;

        amountAOut = (reserveA * amountBWithFee) / (reserveB + amountBWithFee);

        // Evitamos dejar reserva A en cero
        require(reserveA - amountAOut >= 1, "Reserve cannot drop to zero");

        reserveB += amountBIn;
        reserveA -= amountAOut;

        tokenB.transferFrom(msg.sender, address(this), amountBIn);
        tokenA.transfer(msg.sender, amountAOut);

        emit Swapped(msg.sender, address(tokenB), amountBIn, amountAOut);
    }

    /*Devuelve el precio relativo entre los tokens basado en las reservas.
    * Usa 1e18 para normalizar el resultado a 18 decimales (estándar común en tokens).
    * Es una función view, no modifica el estado de la blockchain.
    */
    function getPrice(address _token) external view returns (uint256 price) {
        require(_token == address(tokenA) || _token == address(tokenB), "Invalid token");

        if (_token == address(tokenA)) {
            return reserveB * 1e18 / reserveA; // Precio de A en B
        } else {
            return reserveA * 1e18 / reserveB; // Precio de B en A
        }
    }
}