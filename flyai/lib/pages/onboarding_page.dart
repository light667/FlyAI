import 'package:flutter/material.dart';
import 'package:flyai/pages/signin_page.dart';
import 'package:flyai/widgets/onboarding.dart';

class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});

  @override
  OnboardingPageState createState() => OnboardingPageState();
}

class OnboardingPageState extends State<OnboardingPage> {
  final PageController _pageController = PageController();
  int currentPage = 0;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      extendBodyBehindAppBar: true,
      backgroundColor: Colors.black,
      appBar: AppBar(
        toolbarHeight: 80,
        backgroundColor: Colors.transparent,
        leading: const Image(image: AssetImage("assets/images/symbol.png")),
        actions: [
          TextButton(
            onPressed: () {},
            child: const Text(
              "PRIVACY",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
          TextButton(
            onPressed: () {},
            child: const Text(
              "SIGN IN",
              style: TextStyle(
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          PageView(
            controller: _pageController,
            onPageChanged: (index) {
              setState(() {
                currentPage = index;
              });
            },
            children: [
              Onboarding(
                title: "Trouvez les bourses qui vous correspondent",
                description:
                    "Découvrez des milliers de bourses académiques adaptées à votre profil, vos objectifs et votre parcours.",
                image: "assets/images/onboarding1.jpg",
              ),
              Onboarding(
                title: "Swipez. Matchez. Postulez.",
                description:
                    "Parcourez les opportunités en quelques gestes. Likez les bourses qui vous intéressent et laissez Fly AI identifier les meilleures correspondances.",
                image: "assets/images/onboarding2.jpg",
              ),
              Onboarding(
                title: "L'IA vous accompagne jusqu'à la réussite",
                description:
                    "Recevez des conseils personnalisés, préparez votre dossier et augmentez vos chances de décrocher la bourse de vos rêves.",
                image: "assets/images/onboarding3.jpg",
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: List.generate(
                    3,
                    (index) => AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      margin: const EdgeInsets.all(20),
                      height: 10,
                      width: currentPage == index ? 20 : 10,
                      decoration: BoxDecoration(
                        color:
                            currentPage == index ? Colors.blue : Colors.white,
                        borderRadius: BorderRadius.circular(50),
                      ),
                    ),
                  ),
                ),
                SizedBox(height: 20),
                Container(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (context) => const SignInPage()),
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.blue,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(0),
                      ),
                    ),
                    child: Text("Get Started"),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
