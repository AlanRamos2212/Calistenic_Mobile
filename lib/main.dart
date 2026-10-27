import 'package:flutter/material.dart';

import 'services/auth_service.dart';

void main() => runApp(const App());
const bg = Color(0xFF07101B), card = Color(0xFF101D2E), blue = Color(0xFF168BFF);

class App extends StatelessWidget {
  const App({super.key});
  @override Widget build(BuildContext c) => MaterialApp(
    debugShowCheckedModeBanner: false, title: 'CalisthenicTrack',
    theme: ThemeData(brightness: Brightness.dark, scaffoldBackgroundColor: bg, colorScheme: ColorScheme.fromSeed(seedColor: blue, brightness: Brightness.dark)),
    home: const LoginPage());
}
class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginState();
}

class _LoginState extends State<LoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _authService = AuthService();
  bool register = false;
  bool submitting = false;
  bool obscurePassword = true;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateName(String? value) {
    if (!register) return null;
    final name = value?.trim() ?? '';
    if (name.isEmpty || name.length < 2 || name.length > 80) return 'Escribe un nombre válido.';
    return null;
  }

  String? _validateEmail(String? value) {
    final email = value?.trim() ?? '';
    final valid = RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(email);
    if (!valid || email.length > 120) return 'Escribe un correo válido.';
    return null;
  }

  String? _validatePassword(String? value) {
    final password = value ?? '';
    if (password.length < 8 || password.length > 72) return 'La contraseña debe tener entre 8 y 72 caracteres.';
    return null;
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;

    setState(() => submitting = true);
    try {
      if (register) {
        await _authService.register(
          name: _nameController.text.trim(),
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      } else {
        await _authService.login(
          email: _emailController.text.trim(),
          password: _passwordController.text,
        );
      }

      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Shell()));
    } on AuthException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(error.message)));
    } finally {
      if (mounted) setState(() => submitting = false);
    }
  }

  @override
  Widget build(BuildContext c) => Scaffold(
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(28),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 430),
                child: Form(
                  key: _formKey,
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Container(width: 50, height: 50, decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(15)), child: const Icon(Icons.bolt, size: 30)),
                    const SizedBox(height: 28),
                    Text(register ? 'Crea tu cuenta' : 'Vuelve a entrenar', style: const TextStyle(fontSize: 32, fontWeight: FontWeight.w900)),
                    const SizedBox(height: 8),
                    Text(register ? 'Empieza a construir tu mejor versión.' : 'Tu progreso, tus rutinas, tu ritmo.', style: const TextStyle(color: Colors.blueGrey, fontSize: 16)),
                    const SizedBox(height: 36),
                    if (register) ...[
                      const Text('Nombre'),
                      const SizedBox(height: 8),
                      TextFormField(controller: _nameController, maxLength: 80, validator: _validateName, decoration: const InputDecoration(hintText: 'Alex Rivera', counterText: '')),
                      const SizedBox(height: 18),
                    ],
                    const Text('Correo electrónico'),
                    const SizedBox(height: 8),
                    TextFormField(controller: _emailController, keyboardType: TextInputType.emailAddress, maxLength: 120, validator: _validateEmail, decoration: const InputDecoration(hintText: 'alex@email.com', counterText: '')),
                    const SizedBox(height: 18),
                    const Text('Contraseña'),
                    const SizedBox(height: 8),
                    TextFormField(controller: _passwordController, obscureText: obscurePassword, maxLength: 72, validator: _validatePassword, decoration: InputDecoration(hintText: '••••••••', counterText: '', suffixIcon: IconButton(icon: Icon(obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined), onPressed: () => setState(() => obscurePassword = !obscurePassword)))),
                    const SizedBox(height: 28),
                    SizedBox(width: double.infinity, height: 54, child: FilledButton(onPressed: submitting ? null : _submit, child: submitting ? const SizedBox(width: 22, height: 22, child: CircularProgressIndicator(strokeWidth: 2)) : Text(register ? 'CREAR CUENTA' : 'INICIAR SESIÓN'))),
                    const SizedBox(height: 12),
                    Center(child: TextButton(onPressed: submitting ? null : () => setState(() => register = !register), child: Text(register ? 'Ya tengo una cuenta' : 'Crear una cuenta'))),
                  ]),
                ),
              ),
            ),
          ),
        ),
      );
}
class Shell extends StatefulWidget{const Shell({super.key});@override State<Shell> createState()=>_ShellState();}
class _ShellState extends State<Shell>{int i=0;final pages=const[HomePage(),RoutinesPage(),SocialPage(),AchievementsPage(),ProfilePage()];@override Widget build(BuildContext c)=>Scaffold(body:pages[i],bottomNavigationBar:NavigationBar(backgroundColor:const Color(0xFF091522),selectedIndex:i,onDestinationSelected:(v)=>setState(()=>i=v),destinations:const[
  NavigationDestination(icon:Icon(Icons.home_outlined),selectedIcon:Icon(Icons.home),label:'Inicio'),NavigationDestination(icon:Icon(Icons.fitness_center_outlined),selectedIcon:Icon(Icons.fitness_center),label:'Rutinas'),NavigationDestination(icon:Icon(Icons.people_outline),selectedIcon:Icon(Icons.people),label:'Social'),NavigationDestination(icon:Icon(Icons.emoji_events_outlined),selectedIcon:Icon(Icons.emoji_events),label:'Logros'),NavigationDestination(icon:Icon(Icons.person_outline),selectedIcon:Icon(Icons.person),label:'Perfil') ]));}
class Frame extends StatelessWidget{final String title;final Widget child;const Frame({super.key,required this.title,required this.child});@override Widget build(BuildContext c)=>SafeArea(child:CustomScrollView(slivers:[SliverAppBar(title:Text(title,style:const TextStyle(fontWeight:FontWeight.w900)),floating:true,backgroundColor:bg),SliverPadding(padding:const EdgeInsets.fromLTRB(20,16,20,28),sliver:SliverToBoxAdapter(child:child))]));}
class Label extends StatelessWidget{final String t;const Label(this.t,{super.key});@override Widget build(BuildContext c)=>Text(t,style:const TextStyle(color:blue,fontSize:11,fontWeight:FontWeight.bold,letterSpacing:1.2));}
class Metric extends StatelessWidget{final String v,l;const Metric({super.key,required this.v,required this.l});@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.symmetric(vertical:16),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(14)),child:Column(children:[Text(v,style:const TextStyle(color:blue,fontSize:20,fontWeight:FontWeight.w900)),const SizedBox(height:4),Text(l,style:const TextStyle(color:Colors.blueGrey,fontSize:9))]));}
class Training extends StatelessWidget{final String title,sub,meta;const Training({super.key,required this.title,required this.sub,required this.meta});@override Widget build(BuildContext c)=>Container(height:150,padding:const EdgeInsets.all(18),decoration:BoxDecoration(borderRadius:BorderRadius.circular(18),gradient:const LinearGradient(colors:[Color(0xFF173A62),Color(0xFF111D2D)])),child:Column(crossAxisAlignment:CrossAxisAlignment.start,mainAxisAlignment:MainAxisAlignment.end,children:[Text(meta,style:const TextStyle(color:blue,fontSize:10,fontWeight:FontWeight.bold)),const SizedBox(height:8),Text(title,style:const TextStyle(fontSize:22,fontWeight:FontWeight.w900)),Text(sub,style:const TextStyle(color:Colors.blueGrey)),const Align(alignment:Alignment.bottomRight,child:Icon(Icons.arrow_forward))]));}
class HomePage extends StatelessWidget{const HomePage({super.key});@override Widget build(BuildContext c)=>Frame(title:'CalisthenicTrack',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[
  const Label('JUEVES, 10 DE OCTUBRE'),const SizedBox(height:8),const Text('Vamos a por ello, Alex.',style:TextStyle(fontSize:23,fontWeight:FontWeight.w900)),const SizedBox(height:28),
  Container(padding:const EdgeInsets.all(18),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(18)),child:const Row(children:[Icon(Icons.local_fire_department,color:Colors.orange,size:32),SizedBox(width:14),Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Text('12 DÍAS',style:TextStyle(fontSize:18,fontWeight:FontWeight.w900)),Text('RACHA ACTUAL',style:TextStyle(color:Colors.blueGrey,fontSize:10))]),Spacer(),Text('MEJOR\n18',textAlign:TextAlign.right)])),const SizedBox(height:28),const Label('PLAN DE HOY'),const SizedBox(height:12),const Training(title:'DOMINA TU PESO',sub:'Fuerza de tirón',meta:'04 EJERCICIOS  ·  28 MIN'),const SizedBox(height:28),const Label('TU ACTIVIDAD'),const SizedBox(height:12),const Row(children:[Expanded(child:Metric(v:'38',l:'SESIONES')),SizedBox(width:8),Expanded(child:Metric(v:'12',l:'RACHA')),SizedBox(width:8),Expanded(child:Metric(v:'16h',l:'TIEMPO'))])]));}
class RoutinesPage extends StatelessWidget{const RoutinesPage({super.key});@override Widget build(BuildContext c)=>Frame(title:'Rutinas',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Label('ENTRENA A TU MANERA'),const SizedBox(height:8),const Text('Tus rutinas',style:TextStyle(fontSize:30,fontWeight:FontWeight.w900)),const SizedBox(height:20),const Wrap(spacing:8,children:[Chip(label:Text('Todas')),Chip(label:Text('Fuerza')),Chip(label:Text('Skills')),Chip(label:Text('Core'))]),const SizedBox(height:16),const Training(title:'BASE DE ACERO',sub:'Tren superior',meta:'28 MIN  ·  INTERMEDIO'),const SizedBox(height:14),const Training(title:'CONTROL TOTAL',sub:'Skills',meta:'35 MIN  ·  AVANZADO'),const SizedBox(height:14),const Training(title:'CORE IMPARABLE',sub:'Core',meta:'24 MIN  ·  INTERMEDIO')]));}
class SocialPage extends StatelessWidget{const SocialPage({super.key});@override Widget build(BuildContext c)=>Frame(title:'Comunidad',child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[const Label('FEED SOCIAL'),const SizedBox(height:8),const Text('La comunidad entrena contigo',style:TextStyle(fontSize:25,fontWeight:FontWeight.w900)),const SizedBox(height:22),const Post(name:'Sofía M.',text:'Nueva rutina completada. La constancia gana.'),const SizedBox(height:14),const Post(name:'Diego R.',text:'Primer muscle-up conseguido.')]));}
class Post extends StatelessWidget{final String name,text;const Post({super.key,required this.name,required this.text});@override Widget build(BuildContext c)=>Container(padding:const EdgeInsets.all(16),decoration:BoxDecoration(color:card,borderRadius:BorderRadius.circular(16)),child:Column(crossAxisAlignment:CrossAxisAlignment.start,children:[Row(children:[const CircleAvatar(radius:18,backgroundColor:blue,child:Icon(Icons.person,size:18)),const SizedBox(width:10),Text(name,style:const TextStyle(fontWeight:FontWeight.bold)),const Spacer(),const Icon(Icons.more_horiz)]),const SizedBox(height:14),Text(text),const SizedBox(height:14),const Text('🏆  Logro desbloqueado',style:TextStyle(color:blue,fontWeight:FontWeight.bold)),const SizedBox(height:14),const Row(children:[Icon(Icons.favorite_border),SizedBox(width:18),Icon(Icons.chat_bubble_outline),SizedBox(width:18),Icon(Icons.share_outlined)])]));}
class AchievementsPage extends StatelessWidget {
  const AchievementsPage({super.key});

  @override
  Widget build(BuildContext c) => Frame(
        title: 'Logros',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Label('TU PROGRESO'),
            const SizedBox(height: 8),
            const Text('Logros', style: TextStyle(fontSize: 30, fontWeight: FontWeight.w900)),
            const SizedBox(height: 6),
            const Text('Cada entrenamiento cuenta. Cada meta deja huella.', style: TextStyle(color: Colors.blueGrey)),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: card,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: blue.withValues(alpha: .35)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(color: blue, borderRadius: BorderRadius.circular(14)),
                    child: const Text('12', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900)),
                  ),
                  const SizedBox(width: 14),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('NIVEL ACTUAL', style: TextStyle(color: Colors.blueGrey, fontSize: 9)),
                        SizedBox(height: 4),
                        Text('ATLETA CONSTANTE', style: TextStyle(fontWeight: FontWeight.w900)),
                        SizedBox(height: 10),
                        LinearProgressIndicator(value: .76, minHeight: 6, backgroundColor: Color(0xFF263348), color: blue),
                        SizedBox(height: 5),
                        Text('38 de 50 sesiones', style: TextStyle(color: Colors.blueGrey, fontSize: 10)),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 28),
            Row(children: [
              const Text('INSIGNIAS', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
              const Spacer(),
              Text('3 / 12', style: const TextStyle(color: blue, fontWeight: FontWeight.bold, fontSize: 12)),
            ]),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: AchievementTile(icon: Icons.local_fire_department, title: 'LA LLAMA', detail: 'Racha de 7 días', unlocked: true)),
              SizedBox(width: 10),
              Expanded(child: AchievementTile(icon: Icons.shield_outlined, title: 'BASE SÓLIDA', detail: '25 sesiones', unlocked: true)),
              SizedBox(width: 10),
              Expanded(child: AchievementTile(icon: Icons.emoji_events_outlined, title: 'PRIMER PODIO', detail: 'Top 3 semanal', unlocked: true)),
            ]),
            const SizedBox(height: 12),
            const Row(children: [
              Expanded(child: AchievementTile(icon: Icons.bolt, title: 'MUSCLE-UP', detail: 'Desbloquea un muscle-up', unlocked: false)),
              SizedBox(width: 10),
              Expanded(child: AchievementTile(icon: Icons.fitness_center, title: 'CENTURIÓN', detail: '100 sesiones', unlocked: false)),
              SizedBox(width: 10),
              Expanded(child: AchievementTile(icon: Icons.people_outline, title: 'INSPIRADOR', detail: '10 logros compartidos', unlocked: false)),
            ]),
            const SizedBox(height: 22),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: card, borderRadius: BorderRadius.circular(16)),
              child: const Row(children: [
                Icon(Icons.flag_outlined, color: blue),
                SizedBox(width: 12),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('PRÓXIMO HITO', style: TextStyle(color: Colors.blueGrey, fontSize: 9)),
                  SizedBox(height: 5),
                  Text('50 entrenamientos', style: TextStyle(fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  LinearProgressIndicator(value: .76, minHeight: 5, backgroundColor: Color(0xFF263348), color: blue),
                ])),
                SizedBox(width: 12),
                Text('38/50', style: TextStyle(color: blue, fontWeight: FontWeight.bold)),
              ]),
            ),
          ],
        ),
      );
}
class AchievementTile extends StatelessWidget{final IconData icon;final String title,detail;final bool unlocked;const AchievementTile({super.key,required this.icon,required this.title,required this.detail,required this.unlocked});@override Widget build(BuildContext c)=>Container(height:138,padding:const EdgeInsets.all(10),decoration:BoxDecoration(color:unlocked?card:const Color(0xFF0D1622),borderRadius:BorderRadius.circular(14),border:Border.all(color:unlocked?blue.withValues(alpha:.25):const Color(0xFF1A2736))),child:Column(children:[Container(width:42,height:42,decoration:BoxDecoration(color:unlocked?blue:const Color(0xFF26303B),borderRadius:BorderRadius.circular(10)),child:Icon(icon,color:unlocked?Colors.white:Colors.black54)),const SizedBox(height:10),Text(title,textAlign:TextAlign.center,style:TextStyle(fontSize:10,fontWeight:FontWeight.w900,color:unlocked?Colors.white:Colors.blueGrey)),const SizedBox(height:5),Text(detail,textAlign:TextAlign.center,maxLines:2,overflow:TextOverflow.ellipsis,style:const TextStyle(fontSize:8,color:Colors.blueGrey))]));}
class ProfilePage extends StatelessWidget{const ProfilePage({super.key});@override Widget build(BuildContext c)=>Frame(title:'Perfil',child:Column(children:[const SizedBox(height:20),const CircleAvatar(radius:44,backgroundColor:blue,child:Text('AR',style:TextStyle(fontSize:25,fontWeight:FontWeight.bold))),const SizedBox(height:18),const Text('ALEX RIVERA',style:TextStyle(fontSize:24,fontWeight:FontWeight.w900)),const SizedBox(height:5),const Text('Calistenia · Nivel intermedio',style:TextStyle(color:Colors.blueGrey)),const SizedBox(height:28),const Row(children:[Expanded(child:Metric(v:'38',l:'SESIONES')),Expanded(child:Metric(v:'12',l:'RACHA')),Expanded(child:Metric(v:'16h',l:'TIEMPO'))]),const SizedBox(height:24),const ListTile(leading:Icon(Icons.watch_outlined,color:blue),title:Text('Wearable'),subtitle:Text('Sincronizado con CalisthenicTrack'),trailing:Icon(Icons.check_circle,color:Colors.greenAccent)),const ListTile(leading:Icon(Icons.settings_outlined),title:Text('Preferencias'),trailing:Icon(Icons.chevron_right))]));}
