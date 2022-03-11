public with sharing class OrderItemHelper {
    public OrderItemHelper() {}

    //Metodo responsavel pela atualização do valor do frete (Calcula a partir de uma atualização no pedido)
    public static List<Order> calcFreight(Map<Id, OrderItem> oldMap, Map<Id, OrderItem> newMap) {
        Set<Id> orderIds = new Set<Id>();

        //Realiza a interação dos itens do pedido e verifica se ocorreram alteração nos registros, caso sim atualiza o Set de OrderIds
        for (OrderItem newItem : newMap.values()) {
            OrderItem oldItem = oldMap.get(newItem.Id);

            if ((newItem.Quantity != oldItem.Quantity) || 
                (newItem.Volume__c != oldItem.Volume__c) || 
                (newItem.Weight__c != oldItem.Weight__c)) {
                orderIds.add(newItem.OrderId);
            }
        }

        //Faz uma busca no banco de dados e retorna dos dados de localização do pedido (Referente a conta vinculada)
        Map<Id, Order> orderMap = new Map<Id, Order>([
            SELECT Id, AccountId, Account.City__c, Account.City__r.State__c, Account.CEP__c
            FROM Order
            WHERE Id IN: orderIds
        ]);

        List<Freight__c> freightFindList = findFreight(orderMap);
        List<AggregateResult> aggregateResultList = aggregateOrderItems(orderIds);
        List<Order> orderList = aggregateOrderFreight(aggregateResultList, freightFindList, orderMap);
        return orderList;
    }   

    //Metodo responsavel pelo calculo do frete (Calcula a partir de uma inserção no pedido)
    public static List<Order> calcFreight(List<OrderItem> orderItemList){
        Set<Id> orderIds = new Set<Id>();

        //Realiza a interação dos intens do pedido e adiciona ao Set de OrderIds
        for (OrderItem orderItem : orderItemList){
            orderIds.add(orderItem.OrderId);
        }

        //Faz uma busca no banco de dados e retorna dos dados de localização do pedido (Referente a conta vinculada) 
        Map <Id, Order> orderMap = new Map<Id, Order>([
            SELECT Id, AccountId, Account.City__c, Account.City__r.State__c, Account.CEP__c
            FROM Order
            WHERE Id IN: orderIds
        ]);

        List<Freight__c> freightFindList = findFreight(orderMap);
        List<AggregateResult> aggregateResultList =  aggregateOrderItems(orderIds);
        List<Order> orderList = aggregateOrderFreight(aggregateResultList, freightFindList, orderMap);

        return orderList;
    }

    //Metodo responsavel por realizar a buscas dos fretes em relação a localização do pedido
    public static List<Freight__c> findFreight(Map<Id, Order> orderMap) {
        Set<Id> cityIds = new Set<Id>();
        Set<Id> stateIds = new Set<Id>();
        Set<String> cepIds = new Set<String>();

        //Realiza a interação dos valores do pedido e armazena as informações de localização (En relação aos dados da conta)
        for (Order order : orderMap.values()) {
            cepIds.add(order.Account.CEP__c);
            cityIds.add(order.Account.City__c);
            stateIds.add(order.Account.City__r.State__c);
        }

        //Realiza a busca no banco de dados das informações de localização e ordena com base no valor do score de cada frete
        List<Freight__c> freightFindList = [
            SELECT Id, Name, CEP__c, City__c, State__c, DistributionCenter__c, FreightByWeight__c, FreightByVolumn__c, FreightBase__c 
            FROM Freight__c
            WHERE CEP__c IN: cepIds OR
            City__c IN: cityIds OR
            State__c IN: stateIds
            ORDER BY Score__c DESC, DistributionCenter__c
        ];

        return freightFindList;
    }

    //Metodo responsavel por agregar os valores referentes aos pedidos realizando a soma de todos os itens contidos nele
    public static List<AggregateResult> aggregateOrderItems(Set<Id> orderIds) {
        
        List<AggregateResult> aggregateResultList = [
            SELECT OrderId, SUM(Weight__c) SumWeight, SUM(Volume__c) SumVolume, SUM(Quantity) SumQuantity 
            FROM OrderItem 
            WHERE OrderId IN: orderIds 
            GROUP BY OrderId
        ];

        return aggregateResultList;
    }


    public static List<Order> aggregateOrderFreight(List<AggregateResult> resultList, List<Freight__c> freightList, Map<Id, Order> orderMap) {
        Map<Id, Map<Id, Score>> orderFreightMap = new Map<Id, Map<Id, Score>>();

        //Realiza a interação entre os pedidos e os fretes para definição da prioridade (Score mais elevado)
        for (Order order : orderMap.values()) {
            for (Freight__c freight : freightList) {
                Id distributionId = freight.DistributionCenter__c;
                Integer priorityScore = 0;

                //CEP - Prioridade 1
                if (order.Account.CEP__c == freight.CEP__c) {
                    priorityScore += 15;
                }
 
                //Cidade - Prioridade 2
                if (order.Account.City__c == freight.City__c) {
                    priorityScore += 10;
                }

                //Estado - Prioridade 3
                if (order.Account.City__r.State__c == freight.State__c) {
                    priorityScore += 5;
                }

                if (priorityScore > 0) {
                    if (orderFreightMap.containsKey(order.Id)) {
                        if(!orderFreightMap.get(order.Id).containsKey(distributionId)) {
                            orderFreightMap.get(order.Id).put(distributionId, new Score(freight, priorityScore));
                        } 
                        else if (orderFreightMap.get(order.Id).get(distributionId).priorityScore < priorityScore) {
                            orderFreightMap.get(order.Id).put(distributionId, new Score(freight, priorityScore));
                        }
                    }
                    else {
                        orderFreightMap.put(order.Id,new Map<Id, Score>{ distributionId => new Score(freight, priorityScore)} 
                        );
                    }
                }
            }
        }

        //Realiza a interação dos valores resultates da lista de agregação com base nos pedidos
        for (AggregateResult result : resultList) {
            Id orderId = (Id)result.get('OrderId');
            Decimal totalWeight = (Decimal)result.get('SumWeight');
            Decimal totalVolume = (Decimal)result.get('SumVolume');
            Decimal totalQuantity = (Decimal)result.get('SumQuantity');
            Id bestFreightId = null;
            Id bestDistributionId = null;
            Decimal bestFreightPrice = 0;
            
            for (Id distributionId : orderFreightMap.get(orderId).keySet()) {
                Freight__c freight = orderFreightMap.get(orderId).get(distributionId).freight;
                Decimal freightPrice = bestPrice(freight, totalWeight, totalVolume, totalQuantity);

                if (freightPrice < bestFreightPrice || bestFreightPrice == 0) {
                    bestFreightPrice = freightPrice;
                    bestFreightId = freight.Id;
                    bestDistributionId = distributionId;
                }
            }
            
            Order order = orderMap.get(orderId);
            order.Freight__c = bestFreightId;
            order.TotalFreight__c = bestFreightPrice;
            order.DistributionCenter__c = bestDistributionId;
        }

        //Realiza uma interação dos pedidos e adiciona os pedidos atualizados a lista
        List<Order> orderList = new List<Order>();

        for (Order order : orderMap.values()) {
            orderList.add(order);
        }

        return orderList;
    }


    //Metodo responsavel por definir o melhor valor de frete
    public static Decimal bestPrice(Freight__c freight, Decimal totalWeight, Decimal totalVolume, Decimal totalQuantity) {

        //Realiza o calculo de cada um dos tipos de frete seguindo a premissa: Soma(Valores dos itens do pedido) * valor definido para o tipo de frete
        Decimal WeightPrice = totalWeight * freight.FreightByWeight__c;
        Decimal VolumePrice = totalVolume * freight.FreightByVolumn__c;
        Decimal QuantityPrice = totalQuantity * freight.FreightBase__c;
        Decimal freightPrice = 0;

        //Verifica qual o maior frete dentre as três opções calculadas
        if((WeightPrice < VolumePrice) && (QuantityPrice < VolumePrice)){
            freightPrice = VolumePrice;
        }else if((VolumePrice < WeightPrice) && (QuantityPrice < WeightPrice)){
            freightPrice = WeightPrice;
        }else{
            freightPrice = QuantityPrice;
        }

        return freightPrice;
    }

    //Classe responsavel pela compatibilização do score do frete
    public class Score {
        Freight__c freight {get; set;}
        Integer priorityScore {get; set;}
    
        public Score() {}
            
         public Score(Freight__c freight, Integer priorityScore) {
            this.freight = freight;
            this.priorityScore = priorityScore;
        }
    }  

}
