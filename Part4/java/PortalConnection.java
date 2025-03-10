
import java.sql.*; // JDBC stuff.
import java.util.Properties;

public class PortalConnection {

    // Set this to e.g. "portal" if you have created a database named portal
    // Leave it blank to use the default database of your database user
    static final String DBNAME = "barra";
    // For connecting to the portal database on your local machine
    static final String DATABASE = "jdbc:postgresql://localhost/"+DBNAME;
    static final String USERNAME = "postgres";
    static final String PASSWORD = "bky2002bky";

    // This is the JDBC connection object you will be using in your methods.
    private Connection conn;

    public PortalConnection() throws SQLException, ClassNotFoundException {
        this(DATABASE, USERNAME, PASSWORD);  
    }

    // Initializes the connection, no need to change anything here
    public PortalConnection(String db, String user, String pwd) throws SQLException, ClassNotFoundException {
        Class.forName("org.postgresql.Driver");
        Properties props = new Properties();
        props.setProperty("user", user);
        props.setProperty("password", pwd);
        conn = DriverManager.getConnection(db, props);
    }


    // Register a student on a course, returns a tiny JSON document (as a String)
    public String register(String student, String courseCode) {
      try {
          try (PreparedStatement ps = conn.prepareStatement(
                  "INSERT INTO Registrations VALUES (?, ?, 'registered')")) {
              ps.setString(1, student);
              ps.setString(2, courseCode);
              ps.executeUpdate();
              return "{\"success\":true}";
          }
      } catch (SQLException e) {
          return "{\"success\":false, \"error\":\"" + getError(e) + "\"}";
      }
  }

  public String unregister(String student, String courseCode) {
    try {
        try (Statement stmt = conn.createStatement()) {

            String query = "DELETE FROM Registrations WHERE student = '" + student + 
                          "' AND course = '" + courseCode + "'";
            
            // Execute the vulnerable query
            int rowsAffected = stmt.executeUpdate(query);
            
            if (rowsAffected > 0) {
                return "{\"success\":true}";
            } else {
                return "{\"success\":false, \"error\":\"Student is not registered or waiting for course\"}";
            }
        }
    } catch (SQLException e) {
        return "{\"success\":false, \"error\":\"" + getError(e) + "\"}";
    }
}

    // Return a JSON document containing lots of information about a student, it should validate against the schema found in information_schema.json
public String getInfo(String student) throws SQLException {
    try(PreparedStatement st = conn.prepareStatement(
        "SELECT jsonb_build_object(" +
            "'student', bi.idnr, " +
            "'name', bi.name, " +
            "'login', bi.login, " +
            "'program', bi.program, " +
            "'branch', bi.branch, " +
            
            // finished courses array
            "'finished', (" +
                "SELECT COALESCE(jsonb_agg(jsonb_build_object(" +
                    "'course', fc.coursename, " +
                    "'code', fc.course, " +
                    "'credits', fc.credits, " +
                    "'grade', fc.grade" +
                ")), '[]'::jsonb) " +
                "FROM FinishedCourses fc " +
                "WHERE fc.student = bi.idnr" +
            "), " +
            
            // registered courses array
            "'registered', (" +
                "SELECT COALESCE(jsonb_agg(jsonb_build_object(" +
                    "'course', c.name, " +
                    "'code', r.course, " +
                    "'status', r.status, " +
                    "'position', wl.position" +
                ")), '[]'::jsonb) " +
                "FROM Registrations r " +
                "JOIN Courses c ON r.course = c.code " +
                "LEFT JOIN WaitingList wl ON r.student = wl.student AND r.course = wl.course " +
                "WHERE r.student = bi.idnr" +
            "), " +
            
            // additional required fields from PathToGraduation
            "'seminarCourses', (" +
                "SELECT COALESCE(ptg.seminarcourses, 0) " +
                "FROM PathToGraduation ptg " +
                "WHERE ptg.student = bi.idnr" +
            "), " +
            "'mathCredits', (" +
                "SELECT COALESCE(ptg.mathcredits, 0) " +
                "FROM PathToGraduation ptg " +
                "WHERE ptg.student = bi.idnr" +
            "), " +
            "'totalCredits', (" +
                "SELECT COALESCE(ptg.totalcredits, 0) " +
                "FROM PathToGraduation ptg " +
                "WHERE ptg.student = bi.idnr" +
            "), " +
            "'canGraduate', (" +
                "SELECT COALESCE(ptg.qualified, false) " +
                "FROM PathToGraduation ptg " +
                "WHERE ptg.student = bi.idnr" +
            ")" +
        ") AS jsondata " +
        "FROM BasicInformation bi " +
        "WHERE bi.idnr = ?")) {
        
        st.setString(1, student);
        ResultSet rs = st.executeQuery();
        
        if(rs.next())
            return rs.getString("jsondata");
        else
            return "{\"student\":\"does not exist :(\"}"; 
    }
}


    // This is a hack to turn an SQLException into a JSON string error message. No need to change.
    public static String getError(SQLException e){
       String message = e.getMessage();
       int ix = message.indexOf('\n');
       if (ix > 0) message = message.substring(0, ix);
       message = message.replace("\"","\\\"");
       return message;
    }
}