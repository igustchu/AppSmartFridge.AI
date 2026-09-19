import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:app_links/app_links.dart';

import 'package:test_app/screens/login_screen.dart';
import 'package:test_app/screens/reset_password_screen.dart';
import 'services/notification_service.dart';


final GlobalKey<NavigatorState> navigatorKey =
GlobalKey<NavigatorState>();





Future<void> main() async {

  WidgetsFlutterBinding.ensureInitialized();


  await Supabase.initialize(

    url: 'https://qwxjxtzyowhhkhkjtjhj.supabase.co',

    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InF3eGp4dHp5b3doaGtoa2p0amhqIiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODI4MjE5OTQsImV4cCI6MjA5ODM5Nzk5NH0.Xvl_9Rf40Ge1hIL7u5MRREPbctNKJyOJJt_AuckeR1A',

  );


  await NotificationService.init();

  // ถ้ามีเซสชันผู้ใช้ค้างอยู่แล้ว (เปิดแอปโดยไม่ต้อง login ใหม่) ให้ซิงก์
  // แจ้งเตือนวันหมดอายุทันทีตั้งแต่แอปเปิด ไม่ต้องรอให้ไปเปิดหน้าคลังก่อน
  // (fire-and-forget ไม่ให้บล็อกการเปิดแอป)
  NotificationService.scheduleExpiryReminders().catchError((_) {});


await Future.delayed(
  const Duration(seconds: 3)
);







  runApp(
    const MyApp(),
  );

}








class MyApp extends StatefulWidget {


  const MyApp({super.key});


  @override
  State<MyApp> createState() =>
      _MyAppState();


}








class _MyAppState extends State<MyApp> {



  final appLinks = AppLinks();





  @override
  void initState(){


    super.initState();


    initDeepLink();


  }








  Future<void> initDeepLink() async {



    // กรณีกดลิงก์ตอน App ปิดอยู่

    final initialUri =
    await appLinks.getInitialLink();



    if(initialUri != null){

      handleDeepLink(initialUri);

    }






    // กรณีกดลิงก์ตอน App เปิดอยู่

    appLinks.uriLinkStream.listen((uri){


      handleDeepLink(uri);


    });



  }









  Future<void> handleDeepLink(Uri uri) async {



    print("Deep Link : $uri");




    if(uri.scheme == "smartfridge" &&

        uri.host == "reset-password"){





      try{



        await Supabase.instance.client.auth
            .getSessionFromUrl(uri);





        Future.delayed(

          const Duration(milliseconds:500),

              (){


            navigatorKey.currentState
                ?.pushReplacement(



              MaterialPageRoute(



                builder:(_)=>

                const ResetPasswordScreen(),



              ),



            );


          },

        );





      }catch(e){


        print(
            "Reset link error : $e"
        );


      }



    }



  }









  @override
  Widget build(BuildContext context) {


    return MaterialApp(


      debugShowCheckedModeBanner:false,



      navigatorKey:
      navigatorKey,



      theme:
      ThemeData(



        primarySwatch:
        Colors.orange,



        // ฟอนต์ตรงตามดีไซน์ Figma (Inter) แทนของเดิมที่พิมพ์ชื่อฟอนต์ผิด
        // จน Flutter มองไม่เห็นและใช้ฟอนต์ default ของเครื่องแทนมาตลอด
        // ใช้ไฟล์ฟอนต์ที่แนบมากับแอปเอง (ประกาศไว้ใน pubspec.yaml) แทนการให้
        // google_fonts โหลดจากเน็ตตอนเปิดแอป เพื่อไม่ให้พลาดกรณีไม่มีอินเทอร์เน็ต
        fontFamily:
        'Inter',



        scaffoldBackgroundColor:
        const Color(0xFFFFF9E6),




        appBarTheme:
        const AppBarTheme(



          backgroundColor:
          Colors.transparent,



          elevation:
          0,



          iconTheme:
          IconThemeData(

            color:
            Colors.black,

          ),



        ),






        elevatedButtonTheme:
        ElevatedButtonThemeData(



          style:
          ElevatedButton.styleFrom(



            backgroundColor:
            const Color(0xffffd84d),



            foregroundColor:
            const Color(0xff5189C9),



            shape:
            RoundedRectangleBorder(



              borderRadius:
              BorderRadius.circular(25),



            ),



          ),



        ),



      ),






      home:
      const LoginScreen(),



    );


  }


}