public class TestPortal {

   // enable this to make pretty printing a bit more compact
   private static final boolean COMPACT_OBJECTS = false;

   // This class creates a portal connection and runs a few operation

   public static void main(String[] args) {
      
      try{
         
         PortalConnection c = new PortalConnection();

         // 1. List info for a student
         System.out.println("TEST 1: List info for student 2222222222");
         prettyPrint(c.getInfo("2222222222"));
         pause();

         // 2. Register student for unrestricted course and verify registration
         System.out.println("TEST 2: Register student for unrestricted course CCC555");
         System.out.println(c.register("2222222222", "CCC555"));
         System.out.println("Checking student info after registration:");
         prettyPrint(c.getInfo("2222222222"));
         pause();

         // 3. Register same student for same course again, check for error
         System.out.println("TEST 3: Try registering for same course again");
         System.out.println(c.register("2222222222", "CCC555"));
         pause();

         // 4. Unregister, then unregister again, check for appropriate responses
         System.out.println("TEST 4: Unregister student from course");
         System.out.println(c.unregister("2222222222", "CCC555"));
         System.out.println("Checking student info after unregistration:");
         prettyPrint(c.getInfo("2222222222"));
         System.out.println("Try unregistering again (should fail):");
         System.out.println(c.unregister("2222222222", "CCC555"));
         pause();

         // 5. Register for course without prerequisites, check for error
         System.out.println("TEST 5: Register for course without prerequisites");
         System.out.println(c.register("6666666666", "CCC444"));
         pause();

         // 6. Unregister from restricted course with waiting students,
         //    then register again and check waiting list position
         System.out.println("TEST 6: Setup waiting list");
         System.out.println("Registering students for limited course CCC222:");
         System.out.println(c.register("5555555555", "CCC222"));
         System.out.println(c.register("6666666666", "CCC222"));
         System.out.println("Checking waiting list positions:");
         prettyPrint(c.getInfo("5555555555"));
         prettyPrint(c.getInfo("6666666666"));

         System.out.println("Unregistering 5555555555 from CCC222:");
         System.out.println(c.unregister("5555555555", "CCC222"));
         System.out.println("Registering 5555555555 again for CCC222 (should be last in waiting list):");
         System.out.println(c.register("5555555555", "CCC222"));
         prettyPrint(c.getInfo("5555555555"));
         pause();

         // 7. Unregister and re-register for restricted course, check position
         System.out.println("TEST 7: Unregister and re-register same student");
         System.out.println("Unregistering student 5555555555 from CCC222:");
         System.out.println(c.unregister("5555555555", "CCC222"));
         System.out.println("Re-registering student 5555555555 for CCC222:");
         System.out.println(c.register("5555555555", "CCC222"));
         System.out.println("Checking final position (should be last again):");
         prettyPrint(c.getInfo("5555555555"));
         pause();

         // 8. Unregister from overfull course, check that no waiting students move
         System.out.println("TEST 8: Unregister from overfull course");
         System.out.println("CCC333 is already overfull with 3 students (capacity 2)");
         System.out.println("Registering another student for CCC333 (should go to waiting list):");
         System.out.println(c.register("5555555555", "CCC333"));
         System.out.println("Unregistering student 3333333333 from overfull course:");
         System.out.println(c.unregister("3333333333", "CCC333"));
         System.out.println("Checking if waiting student moved (should still be waiting):");
         prettyPrint(c.getInfo("5555555555"));
         pause();

         // 9. SQL injection to delete all registrations
         System.out.println("TEST 9: SQL Injection attack");
         System.out.println("Running SQL injection to delete all registrations:");
         System.out.println(c.unregister("1111111111", "' OR '1'='1"));
         System.out.println("Checking registrations after attack (should be empty):");
         prettyPrint(c.getInfo("1111111111"));
         prettyPrint(c.getInfo("2222222222"));
        
      
      
      } catch (ClassNotFoundException e) {
         System.err.println("ERROR!\nYou do not have the Postgres JDBC driver (e.g. postgresql-42.5.1.jar) in your runtime classpath!");
      } catch (Exception e) {
         e.printStackTrace();
      }
   }
   
   
   
   public static void pause() throws Exception{
     System.out.println("PRESS ENTER");
     while(System.in.read() != '\n');
   }
   
   // This is a truly horrible and bug-riddled hack for printing JSON. 
   // It is used only to avoid relying on additional libraries.
   // If you are a student, please avert your eyes.
   public static void prettyPrint(String json){
      System.out.print("Raw JSON:");
      System.out.println(json);
      System.out.println("Pretty-printed (possibly broken):");
      
      int indent = 0;
      json = json.replaceAll("\\r?\\n", " ");
      json = json.replaceAll(" +", " "); // This might change JSON string values :(
      json = json.replaceAll(" *, *", ","); // So can this
      
      for(char c : json.toCharArray()){
        if (c == '}' || c == ']') {
          indent -= 2;
          breakline(indent); // This will break string values with } and ]
        }
        
        System.out.print(c);
        
        if (c == '[' || c == '{') {
          indent += 2;
          breakline(indent);
        } else if (c == ',' && !COMPACT_OBJECTS) 
           breakline(indent);
      }
      
      System.out.println();
   }
   
   public static void breakline(int indent){
     System.out.println();
     for(int i = 0; i < indent; i++)
       System.out.print(" ");
   }   
}
