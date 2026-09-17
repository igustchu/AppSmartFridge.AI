import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:test_app/services/notification_service.dart';

import '../widgets/app_bottom_nav.dart';


class ExpirationAlertScreen extends StatefulWidget {

  const ExpirationAlertScreen({super.key});


  @override
  State<ExpirationAlertScreen> createState() =>
      _ExpirationAlertScreenState();

}



class _ExpirationAlertScreenState
    extends State<ExpirationAlertScreen> {


  final supabase =
      Supabase.instance.client;



  int selectedDays = 3;


  String selectedCategory = "ทั้งหมด";


  List<Map<String,dynamic>> items = [];


  bool loading = true;




  @override
void initState(){

  super.initState();


  loadItems();

}










  Future<void> loadItems() async {


    final user =
        supabase.auth.currentUser;


    if(user == null){

      return;

    }




    final data = await supabase

        .from('fridge_items')

        .select()

        .eq(

        'user_id',

        user.id

    );





    final now =
    DateTime.now();




    final result = data.where((item){


      if(item['expiry_date'] == null){

        return false;

      }




      final expiry = DateTime.parse(

          item['expiry_date'].toString()

      );



      final remain = expiry

          .difference(now)

          .inDays;




      return remain >=0 &&

          remain <= selectedDays;



    }).map<Map<String,dynamic>>((e){


      return Map<String,dynamic>.from(e);


    }).toList();






    // เรียงวันหมดอายุใกล้สุดขึ้นก่อน

    result.sort((a,b){


      return DateTime.parse(

          a['expiry_date'].toString()

      ).compareTo(

          DateTime.parse(

              b['expiry_date'].toString()

          )

      );


    });





    setState((){


      items = result;


      loading = false;
      


    });
    if(result.isNotEmpty){


}



  }







  void changeDays(int day){


    setState((){


      selectedDays = day;


      loading = true;


    });



    loadItems();



  }








  List<String> categories(){


    final list = items.map((item){


      return item['category']?.toString()

          ?? "อื่นๆ";


    }).toSet().toList();



    list.sort();



    return [

      "ทั้งหมด",

      ...list

    ];


  }








  List<Map<String,dynamic>> filteredItems(){



    if(selectedCategory == "ทั้งหมด"){

      return items;

    }




    return items.where((item){


      return

        (item['category']?.toString()

            ?? "อื่นๆ")

            == selectedCategory;



    }).toList();



  }









  String categoryEmoji(String category){


    if(category.contains("ผลไม้")){

      return "🍎";

    }


    if(category.contains("ผัก")){

      return "🥕";

    }


    if(category.contains("เนื้อ") ||

        category.contains("หมู") ||

        category.contains("ไก่") ||

        category.contains("ปลา")){

      return "🥩";

    }


    if(category.contains("ข้าว") ||

        category.contains("แป้ง")){

      return "🍞";

    }


    if(category.contains("นม") ||

        category.contains("เครื่องดื่ม")){

      return "🥛";

    }


    if(category.contains("ขนม")){

      return "🍬";

    }


    return "📦";


  }








  String formatDate(String date){


    final d =
    DateTime.parse(date);


    return "${d.day}/${d.month}/${d.year+543}";


  }








  int remainDays(String date){


    return DateTime.parse(date)

        .difference(DateTime.now())

        .inDays;


  }








  Color cardColor(int days){



    if(days <=1){


      return const Color(0xfffdeae4);


    }



    else if(days <=3){


      return const Color(0xfffff7d0);


    }



    else{


      return Colors.white;


    }


  }
  @override
  Widget build(BuildContext context){


    return Scaffold(

      backgroundColor:
      const Color(0xffD8EEFF),


      body:

      SafeArea(

        child:

        Column(

          children:[


            const SizedBox(height:15),


            buildHeader(),


            const SizedBox(height:15),


            buildDaySelector(),


            const SizedBox(height:15),


            Expanded(

              child:

              loading

                  ?

              const Center(

                child:

                CircularProgressIndicator(),

              )

                  :

              buildContent(),


            ),


          ],


        ),


      ),



      bottomNavigationBar:

      const AppBottomNav(current: AppTab.alert),



    );


  }








  Widget buildHeader(){


    return Padding(

      padding:

      const EdgeInsets.symmetric(

          horizontal:20

      ),



      child:

      Row(

        children:[



          InkWell(

            onTap:(){

              Navigator.pop(context);

            },



            child:

            Container(

              height:45,

              width:45,


              decoration:

              BoxDecoration(

                color:

                const Color(0xfffff7d0),


                borderRadius:

                BorderRadius.circular(20),

              ),



              child:

              const Icon(

                Icons.arrow_back,

              ),


            ),


          ),





          const SizedBox(width:12),




          Expanded(

            child:

            Container(

              height:50,



              decoration:

              BoxDecoration(

                color:

                Colors.white,


                borderRadius:

                BorderRadius.circular(25),



                border:

                Border.all(

                  color:

                  Colors.blue,

                  width:2,

                ),

              ),



              child:

              const Center(

                child:

                Text(

                  "แจ้งเตือนวันหมดอายุ",

                  style:

                  TextStyle(

                    fontWeight:

                    FontWeight.bold,

                    fontSize:16,

                  ),

                ),


              ),


            ),


          ),



        ],


      ),


    );


  }









  Widget buildDaySelector(){


    return Container(

      margin:

      const EdgeInsets.symmetric(

          horizontal:20

      ),



      padding:

      const EdgeInsets.all(15),



      decoration:

      BoxDecoration(

        color:

        Colors.white,


        borderRadius:

        BorderRadius.circular(20),

      ),



      child:

      Column(

        crossAxisAlignment:

        CrossAxisAlignment.start,


        children:[



          const Text(

            "🔔 แจ้งเตือนล่วงหน้า",

            style:

            TextStyle(

              fontSize:16,

              fontWeight:

              FontWeight.bold,

            ),

          ),



          const SizedBox(height:12),





          Wrap(

            spacing:10,


            children:

            [1,3,7,14].map((day){



              final selected =

              selectedDays == day;



              return GestureDetector(


                onTap:(){

                  changeDays(day);

                },



                child:

                Container(

                  padding:

                  const EdgeInsets.symmetric(

                    horizontal:18,

                    vertical:10,

                  ),



                  decoration:

                  BoxDecoration(

                    color:

                    selected

                        ?

                    const Color(0xfffff7d0)

                        :

                    Colors.white,



                    border:

                    Border.all(

                      color:

                      Colors.blue,

                    ),



                    borderRadius:

                    BorderRadius.circular(20),


                  ),



                  child:

                  Text(

                    "$day วัน",

                    style:

                    const TextStyle(

                      fontWeight:

                      FontWeight.bold,

                    ),

                  ),



                ),


              );


            }).toList(),



          ),



        ],


      ),



    );


  }









  Widget buildContent(){


    final showItems =

    filteredItems();



    return ListView(

      padding:

      const EdgeInsets.symmetric(

          horizontal:20

      ),



      children:[



        // จำนวนรายการ


        Container(

          padding:

          const EdgeInsets.all(18),



          decoration:

          BoxDecoration(

            color:

            Colors.white,


            borderRadius:

            BorderRadius.circular(20),

          ),



          child:

          Row(

            children:[



              Container(

                height:55,

                width:55,



                decoration:

                const BoxDecoration(

                  color:

                  Color(0xfffff7d0),


                  shape:

                  BoxShape.circle,

                ),



                child:

                const Icon(

                  Icons.access_time,

                  color:

                  Color(0xff5189C9),

                  size:30,

                ),


              ),




              const SizedBox(width:15),




              Expanded(

                child:

                Column(

                  crossAxisAlignment:

                  CrossAxisAlignment.start,


                  children:[



                    const Text(

                      "ใกล้หมดอายุ",

                      style:

                      TextStyle(

                        fontWeight:

                        FontWeight.bold,

                        fontSize:16,

                      ),

                    ),



                    Text(

                      "${showItems.length} รายการ ภายใน $selectedDays วัน",

                      style:

                      const TextStyle(

                        color:

                        Colors.grey,

                      ),

                    ),



                  ],


                ),


              ),



              Text(

                "${showItems.length}",


                style:

                const TextStyle(

                  fontSize:32,

                  fontWeight:

                  FontWeight.bold,

                  color:

                  Colors.orange,

                ),



              ),



            ],


          ),


        ),




        const SizedBox(height:15),




        const Text(

          "หมวดหมู่",

          style:

          TextStyle(

            fontSize:18,

            fontWeight:

            FontWeight.bold,

          ),


        ),



        const SizedBox(height:10),




        SizedBox(

          height:45,


          child:

          ListView(

            scrollDirection:

            Axis.horizontal,



            children:

            categories().map((cat){



              final selected =

              selectedCategory == cat;



              return GestureDetector(



                onTap:(){

                  setState((){

                    selectedCategory = cat;

                  });

                },



                child:

                Container(

                  margin:

                  const EdgeInsets.only(

                      right:10

                  ),



                  padding:

                  const EdgeInsets.symmetric(

                    horizontal:16,

                    vertical:10,

                  ),



                  decoration:

                  BoxDecoration(

                    color:

                    selected

                        ?

                    const Color(0xfffff7d0)

                        :

                    Colors.white,



                    border:

                    Border.all(

                      color:

                      Colors.blue,

                    ),



                    borderRadius:

                    BorderRadius.circular(20),

                  ),



                  child:

                  Text(

                    "${categoryEmoji(cat)} $cat",


                    style:

                    const TextStyle(

                      fontWeight:

                      FontWeight.bold,

                    ),

                  ),



                ),



              );


            }).toList(),



          ),



        ),




        const SizedBox(height:15),




        ...showItems.map((item){



          final days =

          remainDays(

              item['expiry_date']

          );



          return Container(

            margin:

            const EdgeInsets.only(

                bottom:15

            ),



            padding:

            const EdgeInsets.all(18),



            decoration:

            BoxDecoration(

              color:

              cardColor(days),



              borderRadius:

              BorderRadius.circular(20),

            ),



            child:

            Column(

              crossAxisAlignment:

              CrossAxisAlignment.start,



              children:[



                Row(

                  children:[



                    Text(

                      categoryEmoji(

                          item['category'] ?? ""

                      ),

                      style:

                      const TextStyle(

                        fontSize:32,

                      ),

                    ),



                    const SizedBox(width:12),




                    Expanded(

                      child:

                      Text(

                        item['name'] ??

                            "ไม่ระบุ",


                        style:

                        const TextStyle(

                          fontWeight:

                          FontWeight.bold,

                          fontSize:17,

                        ),

                      ),


                    ),



                  ],


                ),




                const SizedBox(height:10),



                Text(

                  "📥 เพิ่มเข้าตู้เย็น : ${formatDate(item['created_at'])}",

                ),



                Text(

                  "⏳ หมดอายุ : ${formatDate(item['expiry_date'])}",

                ),



                const SizedBox(height:8),



                Text(

                  days <= 1

                      ?

                  "⚠️ ควรใช้วันนี้"

                      :

                  "เหลืออีก $days วัน",

                  style:

                  const TextStyle(

                    fontWeight:

                    FontWeight.bold,

                  ),

                ),



              ],


            ),



          );


        }),



      ],



    );


  }  
  
  
  
  
}