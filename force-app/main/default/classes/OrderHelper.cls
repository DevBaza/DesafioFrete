public with sharing class OrderHelper {
    public OrderHelper() {}

    //Metodo responsavel por verificar os erros definidos na regra de negócio
    public static void checkError(Map<Id, Order> oldMap, Map<Id, Order> newMap){

        //Realiza a interação dos pedidos para verificar os erros
        for (Order newOrder : newMap.values()){
            Order oldOrder = oldMap.get(newOrder.Id);
            //Exibe um erro e bloqueia a operação do usuário ao tentar trocar a conta ou contrato de um pedido, ou em caso de alteração no pedido com seu status em "Activated"
           if ((oldOrder.AccountId != newOrder.AccountId) || (oldOrder.ContractId != newOrder.ContractId)){
                newOrder.addError(Label.AccountModifyError);
            }else if (newOrder.Status == 'Activated' && (oldOrder != newOrder) && (oldOrder.Status == newOrder.Status)){
                newOrder.addError(Label.OrderStatusError);
            }
        }
    }
}


