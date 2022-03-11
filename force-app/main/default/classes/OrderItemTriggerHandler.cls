public with sharing class OrderItemTriggerHandler {
    List<OrderItem> oldRecords {get; set;}
    List<OrderItem> newRecords {get; set;}
    Map<Id, OrderItem> oldMap {get; set;}
    Map<Id, OrderItem> newMap {get; set;}

    public OrderItemTriggerHandler(List<OrderItem> oldRecords, List<OrderItem> newRecords, Map<Id, OrderItem> oldMap, Map<Id, OrderItem> newMap){
        this.oldRecords = oldRecords;
        this.newRecords = newRecords;
        this.oldMap = oldMap;
        this.newMap = newMap;
    }

    public void afterInsert(){
        List<Order> orderList = OrderItemHelper.calcFreight(this.newRecords);
        //Verifica se a lista de pedidos não está vazia
        if (!orderList.isEmpty()) {
            update orderList;
        }
    }

    public void afterUpdate() {
        List<Order> orderList = OrderItemHelper.calcFreight(this.oldMap, this.newMap);
        //Verifica se a lista de pedidos não é nula e não está vazia
        if (orderList != null && !orderList.isEmpty()) {
            update orderList;
        }
    }

    public void afterDelete() {
        List<Order> orderList = OrderItemHelper.calcFreight(this.oldRecords);
        //Verifica se a lista de pedidos não está vazia
        if (!orderList.isEmpty()) {
            update orderList;
        }
    }


}
