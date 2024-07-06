import 'dart:async';
import 'dart:convert';
import 'dart:developer';

import 'package:bloc/bloc.dart';
import 'package:flutter/services.dart';
import 'package:meta/meta.dart';
import 'package:web3_flutter/models/transaction_model.dart';
import 'package:web3dart/web3dart.dart';
import 'package:http/http.dart' as http;
import 'package:web_socket_channel/io.dart';

part 'dashboard_event.dart';
part 'dashboard_state.dart';

class DashboardBloc extends Bloc<DashboardEvent, DashboardState> {
  DashboardBloc() : super(DashboardInitial()) {
    on<DashboardInitialFechEvent>(dashboardInitialFechEvent);
    on<DashboardDepositEvent>(dashboardDepositEvent);
    on<DashboardWithdrawEvent>(dashboardWithdrawEvent);
  }

  List<TransactionModel> transactions = [];
  Web3Client? _web3Client;
  late ContractAbi _abiCode;
  late EthereumAddress _contractAddress;
  late EthPrivateKey _creds;
  int balance = 0;

  // Functions
  late DeployedContract _deployedContract;
  late ContractFunction _deposit;
  late ContractFunction _withdraw;
  late ContractFunction _getBalance;
  late ContractFunction _getAllTransactions;

  FutureOr<void> dashboardInitialFechEvent(
      DashboardInitialFechEvent event, Emitter<DashboardState> emit) async {
    emit(DashboardLoadingState());
    try {
      log("DashboardInitialFechEvent: Starting fetch event");

      String rpcUrl = "http://192.168.1.7:7545";
      String socketUrl = "ws://192.168.1.7:7545";

      String privateKey =
          "0x0902f21e1acaff0cc4124538442d7819b8d237f0bddee5c523bcbd13c964ea53";
      try{
      _web3Client = Web3Client(
        rpcUrl,
        http.Client(),
        socketConnector: () {
          return IOWebSocketChannel.connect(socketUrl).cast<String>();
        },
      );

      log("DashboardInitialFechEvent: Web3Client initialized");

      // getABIR
      String abiFile = await rootBundle
          .loadString('build/contracts/ExpenseManagerContract.json');
      var jsonDecoded = jsonDecode(abiFile);

      _abiCode = ContractAbi.fromJson(
          jsonEncode(jsonDecoded["abi"]), 'ExpenseManagerContract');

      _contractAddress =
          EthereumAddress.fromHex("0xd618Af99350C9d583637ae1fc23935AB5AcA828A");

      _creds = EthPrivateKey.fromHex(privateKey);

      log("DashboardInitialFechEvent: Contract address and credentials set");

      // get deployed contract
      _deployedContract = DeployedContract(_abiCode, _contractAddress);
      _deposit = _deployedContract.function("deposit");
      _withdraw = _deployedContract.function("withdraw");
      _getBalance = _deployedContract.function("getBalance");
      _getAllTransactions = _deployedContract.function("getAllTransactions");

      log("DashboardInitialFechEvent: Deployed contract functions set");

      log("DashboardInitialFechEvent: Fetching transactions...");
      
        final transactionsData = await _web3Client!.call(
            contract: _deployedContract,
            function: _getAllTransactions,
            params: []);
        log("DashboardInitialFechEvent: Transactions data fetched: $transactionsData");

        log("DashboardInitialFechEvent: Fetching balance...");
        final balanceData = await _web3Client!
            .call(contract: _deployedContract, function: _getBalance, params: [
          EthereumAddress.fromHex("0xEE1E3119AbF5B3d90Cf468315Bcb9950facb28d5")
        ]);
        log("DashboardInitialFechEvent: Balance data fetched: $balanceData");

        List<TransactionModel> trans = [];
        for (int i = 0; i < transactionsData[0].length; i++) {
          TransactionModel transactionModel = TransactionModel(
              transactionsData[0][i].toString(),
              transactionsData[1][i].toInt(),
              transactionsData[2][i],
              DateTime.fromMicrosecondsSinceEpoch(
                  transactionsData[3][i].toInt()
                  )
                  );
          trans.add(transactionModel);
        }
        transactions = trans;

        int bal = balanceData[0].toInt();
        balance = bal;

        log("DashboardInitialFechEvent: Transactions converted: $transactions");
        log("DashboardInitialFechEvent: Balance set: $balance");

        emit(DashboardSuccessState(transactions: transactions, balance: balance));
        log("DashboardInitialFechEvent: DashboardSuccessState emitted");
      } catch (fetchError) {
        log("DashboardInitialFechEvent: Fetching error - $fetchError");
        emit(DashboardErrorState());
      }
    } catch (e) {
      log("DashboardInitialFechEvent: Error - $e");
      emit(DashboardErrorState());
    }
  }

  FutureOr<void> dashboardDepositEvent(
      DashboardDepositEvent event, Emitter<DashboardState> emit) async {
    try {
      log("DashboardDepositEvent: Starting deposit event");

      final transaction = Transaction.callContract(
          from: EthereumAddress.fromHex(
              "0x5D7480901251586E43d9224EC4Cc5542cdf99D49"),
          contract: _deployedContract,
          function: _deposit,
          parameters: [
            BigInt.from(event.transactionModel.amount),
            event.transactionModel.reason
          ],
          value: EtherAmount.inWei(BigInt.from(event.transactionModel.amount)
          )
          );

      final result = await _web3Client!.sendTransaction(_creds, transaction,
          chainId: 1337, fetchChainIdFromNetworkId: false);
      log("DashboardDepositEvent: Transaction result - $result");

      add(DashboardInitialFechEvent());
      log("DashboardDepositEvent: DashboardInitialFechEvent added");
    } catch (e) {
      log("DashboardDepositEvent: Error - $e");
    }
  }

  FutureOr<void> dashboardWithdrawEvent(
      DashboardWithdrawEvent event, Emitter<DashboardState> emit) async {
    try {
      log("DashboardWithdrawEvent: Starting withdraw event");

      final transaction = Transaction.callContract(
        from: EthereumAddress.fromHex(
            "0x5D7480901251586E43d9224EC4Cc5542cdf99D49"),
        contract: _deployedContract,
        function: _withdraw,
        parameters: [
          BigInt.from(event.transactionModel.amount),
          event.transactionModel.reason
        ],
      );

      final result = await _web3Client!.sendTransaction(_creds, transaction,
          chainId: 1337, fetchChainIdFromNetworkId: false);
      log("DashboardWithdrawEvent: Transaction result - $result");

      add(DashboardInitialFechEvent());
      log("DashboardWithdrawEvent: DashboardInitialFechEvent added");
    } catch (e) {
      log("DashboardWithdrawEvent: Error - $e");
    }
  }
}
