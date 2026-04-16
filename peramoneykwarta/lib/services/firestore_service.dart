import 'package:cloud_firestore/cloud_firestore.dart';

class FirestoreService {

  final CollectionReference items = FirebaseFirestore.instance.collection('item');

  // create item
  Future<void> insertItem(String itemName){
    return items.add({
      'itemName': itemName,
      'timestamp': Timestamp.now(),
    });
  }

  // read item
  Stream<QuerySnapshot> getItemStream() {
    final itemStream = items.orderBy('timestamp', descending: true).snapshots();
    return itemStream;
  }

  // update item
  Future<void> updateItem(String itemID, String newItemName){
    return items.doc(itemID).update({
      'itemName': newItemName,
      'timestamp': Timestamp.now(),
    });
  }

  // delete item
  Future<void> deleteItem(String itemID){
    return items.doc(itemID).delete();
  }
}