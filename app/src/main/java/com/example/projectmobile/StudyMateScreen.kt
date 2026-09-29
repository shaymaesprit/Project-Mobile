package com.example.projectmobile

import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Card
import androidx.compose.material3.CardDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.NavigationBar
import androidx.compose.material3.NavigationBarItem
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Surface
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.PasswordVisualTransformation
import androidx.compose.ui.text.input.VisualTransformation
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp

private val Teal = Color(0xFF006D77)
private val Mint = Color(0xFF83C5BE)
private val Canvas = Color(0xFFF8FAFC)
private val Ink = Color(0xFF263238)
private val Gold = Color(0xFFFFB703)
private val Muted = Color(0xFF718096)

private data class Course(val name: String, val professor: String, val room: String, val type: String, val time: String)
private data class StudyTask(val title: String, val course: String, val due: String, val priority: String, val status: String)
private data class StudyNote(val title: String, val course: String, val body: String)
private data class StudyEvent(val title: String, val date: String, val kind: String)

@Composable
fun StudyMateApp() {
    var page by rememberSaveable { mutableStateOf("Splash") }
    var dialogType by remember { mutableStateOf("") }
    var dialogIndex by remember { mutableStateOf(-1) }
    var taskFilter by rememberSaveable { mutableStateOf("All") }
    var showDialog by remember { mutableStateOf(false) }
    val courses = remember { mutableStateListOf(
        Course("Human Computer Interaction", "Dr. Amira Benali", "Room B204", "Lecture", "09:00 – 10:30"),
        Course("Database Systems", "Prof. Karim Haddad", "Lab 3", "Practical", "11:00 – 12:30"),
        Course("Software Engineering", "Dr. Lina Mansour", "Room A112", "Tutorial", "14:00 – 15:30")
    ) }
    val tasks = remember { mutableStateListOf(
        StudyTask("Research paper outline", "Human Computer Interaction", "Today, 5:00 PM", "High", "In Progress"),
        StudyTask("SQL exercises — chapter 4", "Database Systems", "Tomorrow", "Medium", "To Do"),
        StudyTask("Sprint retrospective", "Software Engineering", "Fri, Oct 2", "Low", "To Do")
    ) }
    val notes = remember { mutableStateListOf(
        StudyNote("HCI — usability principles", "Human Computer Interaction", "Consistency, feedback, and clear affordances make interfaces easier to use."),
        StudyNote("SQL joins quick review", "Database Systems", "INNER JOIN returns matching rows. LEFT JOIN keeps every row from the left table.")
    ) }
    val events = remember { mutableStateListOf(
        StudyEvent("Database midterm", "Oct 08 · 10:00 AM", "Exam"),
        StudyEvent("Research paper due", "Oct 12 · 11:59 PM", "Deadline"),
        StudyEvent("Study group", "Oct 15 · 3:00 PM", "Personal")
    ) }

    if (showDialog && dialogType.startsWith("Delete ")) {
        val type = dialogType.removePrefix("Delete ")
        AlertDialog(
            onDismissRequest = { showDialog = false },
            title = { Text("Delete $type?") },
            text = { Text("This item will be removed from your study space.") },
            confirmButton = { TextButton(onClick = {
                when (type) {
                    "Course" -> courses.removeAt(dialogIndex)
                    "Task" -> tasks.removeAt(dialogIndex)
                    "Note" -> notes.removeAt(dialogIndex)
                    else -> events.removeAt(dialogIndex)
                }
                showDialog = false
            }) { Text("Delete", color = Color(0xFFB54747)) } },
            dismissButton = { TextButton(onClick = { showDialog = false }) { Text("Cancel") } }
        )
    } else if (showDialog) {
        val initial = when (dialogType) {
            "Course" -> courses.getOrNull(dialogIndex)?.let { "${it.name}\n${it.professor}\n${it.room}\n${it.type}\n${it.time}" }.orEmpty()
            "Task" -> tasks.getOrNull(dialogIndex)?.let { "${it.title}\n${it.course}\n${it.due}\n${it.priority}\n${it.status}" }.orEmpty()
            "Note" -> notes.getOrNull(dialogIndex)?.let { "${it.title}\n${it.course}\n${it.body}" }.orEmpty()
            else -> events.getOrNull(dialogIndex)?.let { "${it.title}\n${it.date}\n${it.kind}" }.orEmpty()
        }
        EntryDialog(dialogType, initial, { showDialog = false }) { values ->
            when (dialogType) {
                "Course" -> {
                    val item = Course(values[0], values.getOrElse(1) { "Professor" }, values.getOrElse(2) { "Room" }, values.getOrElse(3) { "Lecture" }, values.getOrElse(4) { "09:00 – 10:00" })
                    if (dialogIndex >= 0) courses[dialogIndex] = item else courses.add(item)
                }
                "Task" -> {
                    val item = StudyTask(values[0], values.getOrElse(1) { "General" }, values.getOrElse(2) { "Tomorrow" }, values.getOrElse(3) { "Medium" }, values.getOrElse(4) { "To Do" })
                    if (dialogIndex >= 0) tasks[dialogIndex] = item else tasks.add(item)
                }
                "Note" -> {
                    val item = StudyNote(values[0], values.getOrElse(1) { "General" }, values.getOrElse(2) { "Add your thoughts here." })
                    if (dialogIndex >= 0) notes[dialogIndex] = item else notes.add(item)
                }
                else -> {
                    val item = StudyEvent(values[0], values.getOrElse(1) { "Oct 20 · 9:00 AM" }, values.getOrElse(2) { "Personal" })
                    if (dialogIndex >= 0) events[dialogIndex] = item else events.add(item)
                }
            }
            showDialog = false
        }
    }

    val mainPages = setOf("Home", "Courses", "Tasks", "Calendar", "Profile")
    Scaffold(
        containerColor = Canvas,
        bottomBar = {
            if (page in mainPages) NavigationBar(containerColor = Color.White) {
                listOf("Home" to "⌂", "Courses" to "▤", "Tasks" to "✓", "Calendar" to "▦", "Profile" to "●").forEach { (label, icon) ->
                    NavigationBarItem(page == label, { page = label }, icon = { Text(icon, fontSize = 20.sp) }, label = { Text(label) })
                }
            }
        }
    ) { padding ->
        when (page) {
            "Splash" -> SplashScreen({ page = "Home" }, { page = "Login" })
            "Login" -> AuthScreen(false, { page = "Splash" }, { page = "Home" }, { page = "Register" })
            "Register" -> AuthScreen(true, { page = "Login" }, { page = "Home" }, { page = "Login" })
            else -> AppPage(
                page, Modifier.padding(padding), tasks, courses, notes, events, taskFilter,
                { taskFilter = it }, { page = it },
                { type -> dialogType = type; dialogIndex = -1; showDialog = true },
                { type, index -> dialogType = type; dialogIndex = index; showDialog = true },
                { type, index -> dialogType = "Delete $type"; dialogIndex = index; showDialog = true },
                { index -> tasks[index] = tasks[index].copy(status = if (tasks[index].status == "Completed") "To Do" else "Completed") },
                { page = "Login" }
            )
        }
    }
}

@Composable
private fun SplashScreen(onContinue: () -> Unit, onLogin: () -> Unit) {
    val transition = rememberInfiniteTransition(label = "splash")
    val progress by transition.animateFloat(0.35f, 0.85f, infiniteRepeatable(tween(900), RepeatMode.Reverse), label = "progress")
    Box(Modifier.fillMaxSize().background(Teal), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally, modifier = Modifier.padding(32.dp)) {
            Surface(shape = RoundedCornerShape(28.dp), color = Color.White.copy(alpha = .14f), modifier = Modifier.size(104.dp)) {
                Box(contentAlignment = Alignment.Center) { Text("✦", color = Gold, fontSize = 48.sp) }
            }
            Spacer(Modifier.height(22.dp))
            Text("StudentLife", color = Color.White, fontSize = 32.sp, fontWeight = FontWeight.Bold)
            Text("Your University Life, Organized.", color = Color.White.copy(alpha = .8f), fontSize = 15.sp)
            Spacer(Modifier.height(36.dp))
            LinearProgressIndicator(progress = { progress }, color = Gold, trackColor = Color.White.copy(alpha = .25f), modifier = Modifier.width(100.dp).height(4.dp).clip(CircleShape))
            Spacer(Modifier.height(38.dp))
            Button(onClick = onContinue, colors = ButtonDefaults.buttonColors(containerColor = Color.White, contentColor = Teal), modifier = Modifier.fillMaxWidth()) { Text("Explore the app", fontWeight = FontWeight.SemiBold) }
            TextButton(onClick = onLogin) { Text("I already have an account", color = Color.White) }
        }
    }
}

@Composable
private fun AuthScreen(register: Boolean, onBack: () -> Unit, onSubmit: () -> Unit, onSwitch: () -> Unit) {
    var email by rememberSaveable { mutableStateOf("") }
    var password by rememberSaveable { mutableStateOf("") }
    var firstName by rememberSaveable { mutableStateOf("") }
    var lastName by rememberSaveable { mutableStateOf("") }
    var university by rememberSaveable { mutableStateOf("") }
    var academicLevel by rememberSaveable { mutableStateOf("") }
    var speciality by rememberSaveable { mutableStateOf("") }
    var showPassword by remember { mutableStateOf(false) }
    var rememberMe by rememberSaveable { mutableStateOf(true) }
    var error by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().background(Canvas).padding(24.dp), verticalArrangement = Arrangement.Center) {
        Text("‹  Back", color = Teal, modifier = Modifier.clickable { onBack() })
        Spacer(Modifier.height(26.dp))
        Text(if (register) "Create your account" else "Welcome back", fontSize = 28.sp, fontWeight = FontWeight.Bold, color = Ink)
        Text(if (register) "Your organized semester starts here." else "Pick up where you left off.", color = Muted)
        Spacer(Modifier.height(24.dp))
        if (register) {
            TextField("First name", firstName, { firstName = it })
            Spacer(Modifier.height(12.dp))
            TextField("Last name", lastName, { lastName = it })
        }
        Spacer(Modifier.height(12.dp))
        TextField("University email", email, { email = it })
        Spacer(Modifier.height(12.dp))
        OutlinedTextField(password, { password = it }, label = { Text("Password") }, singleLine = true,
            visualTransformation = if (showPassword) VisualTransformation.None else PasswordVisualTransformation(),
            trailingIcon = { Text(if (showPassword) "Hide" else "Show", modifier = Modifier.clickable { showPassword = !showPassword }.padding(8.dp), color = Teal) },
            modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp))
        if (register) {
            Spacer(Modifier.height(12.dp)); TextField("University", university, { university = it })
            Spacer(Modifier.height(12.dp)); TextField("Academic level", academicLevel, { academicLevel = it })
            Spacer(Modifier.height(12.dp)); TextField("Speciality", speciality, { speciality = it })
        } else {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Text(if (rememberMe) "☑  Remember me" else "□  Remember me", color = Muted, modifier = Modifier.weight(1f).clickable { rememberMe = !rememberMe })
                Text("Forgot password?", color = Teal, modifier = Modifier.clickable { error = "Password reset link sent (demo)." })
            }
        }
        if (error.isNotEmpty()) Text(error, color = Teal, modifier = Modifier.padding(top = 8.dp))
        Spacer(Modifier.height(20.dp))
        Button(onClick = {
            val profileIsComplete = firstName.isNotBlank() && lastName.isNotBlank() && university.isNotBlank() && academicLevel.isNotBlank() && speciality.isNotBlank()
            if (email.contains("@") && password.length >= 6 && (!register || profileIsComplete)) onSubmit()
            else error = if (register) "Complete every field with a valid email and 6+ character password." else "Enter a valid email and a password of at least 6 characters."
        }, modifier = Modifier.fillMaxWidth().height(52.dp), shape = RoundedCornerShape(16.dp)) { Text(if (register) "Create account" else "Login") }
        TextButton(onClick = onSwitch, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text(if (register) "Already a member? Log in" else "Create an account", color = Teal) }
    }
}

@Composable
private fun AppPage(
    page: String, modifier: Modifier, tasks: List<StudyTask>, courses: List<Course>, notes: List<StudyNote>, events: List<StudyEvent>, filter: String,
    onFilter: (String) -> Unit, navigate: (String) -> Unit, add: (String) -> Unit, edit: (String, Int) -> Unit,
    delete: (String, Int) -> Unit, toggleTask: (Int) -> Unit, signOut: () -> Unit
) {
    Column(modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 14.dp), verticalAlignment = Alignment.CenterVertically) {
            Column(Modifier.weight(1f)) {
                Text(if (page == "Home") "STUDYMATE" else page.uppercase(), color = Teal, fontSize = 12.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.5.sp)
                Text(when (page) { "Home" -> "Your day, in focus"; "Timetable" -> "Your weekly plan"; "Notes" -> "Ideas worth keeping"; "Notifications" -> "Your updates"; else -> page }, color = Ink, fontSize = 21.sp, fontWeight = FontWeight.Bold)
            }
            Text("♧", fontSize = 21.sp, color = Teal, modifier = Modifier.clickable { navigate("Notifications") }.padding(8.dp))
            Surface(color = Color(0xFFE0F2F1), shape = CircleShape, modifier = Modifier.size(42.dp).clickable { navigate("Profile") }) { Box(contentAlignment = Alignment.Center) { Text("S", color = Teal, fontWeight = FontWeight.Bold) } }
        }
        when (page) {
            "Home" -> HomePage(tasks, navigate)
            "Courses" -> CoursesPage(courses, add, edit, delete)
            "Tasks" -> TasksPage(tasks, filter, onFilter, add, edit, delete, toggleTask)
            "Calendar" -> CalendarPage(events, add, edit, delete)
            "Profile" -> ProfilePage(navigate, signOut)
            "Edit profile" -> EditProfilePage { navigate("Profile") }
            "Change password" -> ChangePasswordPage { navigate("Profile") }
            "Timetable" -> TimetablePage(courses)
            "Notes" -> NotesPage(notes, add, edit, delete)
            "Notifications" -> NotificationsPage()
            else -> HomePage(tasks, navigate)
        }
    }
}

@Composable
private fun HomePage(tasks: List<StudyTask>, navigate: (String) -> Unit) {
    LazyColumn(contentPadding = PaddingValues(start = 20.dp, end = 20.dp, bottom = 24.dp), verticalArrangement = Arrangement.spacedBy(16.dp)) {
        item {
            Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) {
                Column(Modifier.weight(1f)) { Text("Hello, Student! 👋", fontSize = 23.sp, color = Ink, fontWeight = FontWeight.Bold); Text("Tuesday, September 29", color = Muted) }
                Surface(color = Color(0xFFFFF3D2), shape = RoundedCornerShape(14.dp)) { Text("✦  72%", Modifier.padding(12.dp), color = Color(0xFF9A6800), fontWeight = FontWeight.Bold) }
            }
        }
        item { Card(colors = CardDefaults.cardColors(containerColor = Teal), shape = RoundedCornerShape(24.dp)) {
            Column(Modifier.fillMaxWidth().padding(20.dp)) {
                Text("UP NEXT · 9:00 AM", color = Mint, fontWeight = FontWeight.Bold, fontSize = 12.sp, letterSpacing = 1.sp)
                Spacer(Modifier.height(8.dp)); Text("Human Computer\nInteraction", color = Color.White, fontSize = 21.sp, fontWeight = FontWeight.Bold)
                Spacer(Modifier.height(14.dp)); Text("◷  09:00 – 10:30     ⌖  Room B204", color = Color.White.copy(alpha = .85f))
            }
        } }
        item { SectionHeader("Today’s classes", "See timetable") { navigate("Timetable") } }
        item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            StatCard("3", "Classes", "▤", Modifier.weight(1f)); StatCard("${tasks.count { it.status != "Completed" }}", "Pending tasks", "✓", Modifier.weight(1f)); StatCard("2", "Deadlines", "◷", Modifier.weight(1f))
        } }
        item { SectionHeader("Upcoming deadlines", "All tasks") { navigate("Tasks") } }
        items(tasks.filter { it.status != "Completed" }.take(2)) { task ->
            Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
                Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(Modifier.size(40.dp).clip(RoundedCornerShape(12.dp)).background(Color(0xFFFFF3D2)), contentAlignment = Alignment.Center) { Text("!", color = Color(0xFF9A6800), fontWeight = FontWeight.Bold) }
                    Column(Modifier.padding(start = 12.dp).weight(1f)) { Text(task.title, color = Ink, fontWeight = FontWeight.SemiBold); Text("${task.course} · ${task.due}", color = Muted, fontSize = 12.sp) }
                }
            }
        }
        item { SectionHeader("Quick access", null) {} }
        item { Row(horizontalArrangement = Arrangement.spacedBy(10.dp)) {
            QuickAction("▦", "Timetable", Color(0xFFE5F4F2), Modifier.weight(1f)) { navigate("Timetable") }
            QuickAction("✎", "My notes", Color(0xFFFFF3D2), Modifier.weight(1f)) { navigate("Notes") }
            QuickAction("♧", "Updates", Color(0xFFEAF0FF), Modifier.weight(1f)) { navigate("Notifications") }
        } }
        item { Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
            Column(Modifier.padding(16.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text("Weekly progress", fontWeight = FontWeight.Bold, color = Ink); Text("72%", color = Teal, fontWeight = FontWeight.Bold) }
                Spacer(Modifier.height(12.dp)); LinearProgressIndicator(progress = { .72f }, modifier = Modifier.fillMaxWidth().height(8.dp).clip(CircleShape), color = Teal, trackColor = Color(0xFFE5EFEE))
                Spacer(Modifier.height(8.dp)); Text("You’re doing great. Keep the momentum!", color = Muted, fontSize = 13.sp)
            }
        } }
    }
}

@Composable
private fun CoursesPage(courses: List<Course>, add: (String) -> Unit, edit: (String, Int) -> Unit, delete: (String, Int) -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) { Text("${courses.size} courses this semester", color = Muted, modifier = Modifier.weight(1f)); Button({ add("Course") }, shape = RoundedCornerShape(14.dp)) { Text("+ Add") } }
        LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(courses.withIndex().toList()) { (index, course) ->
                Card(shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(42.dp).clip(RoundedCornerShape(14.dp)).background(Color(0xFFE5F4F2)), contentAlignment = Alignment.Center) { Text("▤", color = Teal) }; Column(Modifier.weight(1f).padding(start = 12.dp)) { Text(course.name, color = Ink, fontWeight = FontWeight.Bold); Text(course.type, color = Teal, fontSize = 12.sp) }; Text("⋮", color = Muted, modifier = Modifier.clickable { edit("Course", index) }.padding(8.dp)) }
                        Spacer(Modifier.height(14.dp)); Text("◷  ${course.time}     ⌖  ${course.room}", color = Muted, fontSize = 13.sp); Text("♙  ${course.professor}", color = Muted, fontSize = 13.sp, modifier = Modifier.padding(top = 6.dp))
                        Row(Modifier.align(Alignment.End)) { TextButton({ edit("Course", index) }) { Text("Edit") }; TextButton({ delete("Course", index) }) { Text("Delete", color = Color(0xFFB54747)) } }
                    }
                }
            }
            if (courses.isEmpty()) item { EmptyState("No courses yet", "Add your first course to build your semester.") }
        }
    }
}

@Composable
private fun TasksPage(tasks: List<StudyTask>, filter: String, onFilter: (String) -> Unit, add: (String) -> Unit, edit: (String, Int) -> Unit, delete: (String, Int) -> Unit, toggle: (Int) -> Unit) {
    val completedPercent = if (tasks.isEmpty()) 0 else tasks.count { it.status == "Completed" } * 100 / tasks.size
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) { Text("Stay on top of your work", color = Muted, modifier = Modifier.weight(1f)); Button({ add("Task") }, shape = RoundedCornerShape(14.dp)) { Text("+ Add") } }
        Column(Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 8.dp)) {
            Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { Text("Task progress", color = Ink, fontWeight = FontWeight.SemiBold); Text("$completedPercent%", color = Teal, fontWeight = FontWeight.Bold) }
            LinearProgressIndicator(progress = { completedPercent / 100f }, modifier = Modifier.fillMaxWidth().padding(top = 8.dp).height(6.dp).clip(CircleShape), color = Teal, trackColor = Color(0xFFE5EFEE))
        }
        Row(Modifier.fillMaxWidth().padding(horizontal = 14.dp), horizontalArrangement = Arrangement.spacedBy(4.dp)) { listOf("All", "To Do", "In Progress", "Completed").forEach { FilterChip(filter == it, { onFilter(it) }, label = { Text(it, fontSize = 11.sp) }) } }
        val filtered = tasks.withIndex().filter { filter == "All" || it.value.status == filter }
        LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text("${filtered.size} tasks · ${tasks.count { it.status == "Completed" }} completed", color = Muted, fontSize = 13.sp) }
            items(filtered) { indexed ->
                val task = indexed.value
                Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
                    Column(Modifier.padding(16.dp)) {
                        Row(verticalAlignment = Alignment.CenterVertically) {
                            Text(if (task.status == "Completed") "☑" else "□", color = Teal, fontSize = 22.sp, modifier = Modifier.clickable { toggle(indexed.index) }.padding(end = 10.dp))
                            Column(Modifier.weight(1f)) { Text(task.title, color = Ink, fontWeight = FontWeight.SemiBold); Text("${task.course} · Due ${task.due}", color = Muted, fontSize = 12.sp) }
                            Text(task.priority, color = if (task.priority == "High") Color(0xFFB54747) else Teal, fontSize = 11.sp, fontWeight = FontWeight.Bold)
                        }
                        Spacer(Modifier.height(10.dp)); Text(task.status, color = Muted, fontSize = 12.sp)
                        Row(Modifier.align(Alignment.End)) { TextButton({ edit("Task", indexed.index) }) { Text("Edit") }; TextButton({ delete("Task", indexed.index) }) { Text("Delete", color = Color(0xFFB54747)) } }
                    }
                }
            }
            if (filtered.isEmpty()) item { EmptyState("Nothing to do here", "Tasks that match this filter will appear here.") }
        }
    }
}

@Composable
private fun TimetablePage(courses: List<Course>) {
    var selected by rememberSaveable { mutableStateOf("Tue") }
    val days = listOf("Mon", "Tue", "Wed", "Thu", "Fri")
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 16.dp), horizontalArrangement = Arrangement.SpaceBetween) { days.forEach { day -> FilterChip(selected == day, { selected = day }, label = { Text(day) }) } }
        LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            item { Text("Week of September 28 – October 4 · $selected", color = Muted, fontSize = 13.sp) }
            items(courses) { course -> Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color(0xFFE5F4F2))) {
                Row(Modifier.fillMaxWidth().padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Column(Modifier.width(82.dp)) { Text(course.time.substringBefore(" – "), color = Teal, fontWeight = FontWeight.Bold); Text(course.time.substringAfter("– "), color = Muted, fontSize = 12.sp) }
                    Box(Modifier.width(3.dp).height(56.dp).clip(CircleShape).background(Teal)); Column(Modifier.padding(start = 12.dp)) { Text(course.name, color = Ink, fontWeight = FontWeight.Bold); Text("${course.room} · ${course.professor}", color = Muted, fontSize = 12.sp); Text(course.type, color = Teal, fontSize = 11.sp) }
                }
            } }
            item { OutlinedButton({ selected = days[(days.indexOf(selected) + 1) % days.size] }, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp)) { Text("Next day  →") } }
        }
    }
}

@Composable
private fun NotesPage(notes: List<StudyNote>, add: (String) -> Unit, edit: (String, Int) -> Unit, delete: (String, Int) -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) { Text("Your ideas, all in one place", color = Muted, modifier = Modifier.weight(1f)); Button({ add("Note") }, shape = RoundedCornerShape(14.dp)) { Text("+ Note") } }
        LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
            items(notes.withIndex().toList()) { (index, note) -> Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
                Column(Modifier.fillMaxWidth().padding(16.dp)) { Text(note.course.uppercase(), color = Teal, fontSize = 10.sp, fontWeight = FontWeight.Bold); Text(note.title, color = Ink, fontWeight = FontWeight.Bold, fontSize = 17.sp, modifier = Modifier.padding(top = 8.dp)); Text(note.body, color = Muted, modifier = Modifier.padding(top = 6.dp)); Row(Modifier.align(Alignment.End)) { TextButton({ edit("Note", index) }) { Text("Edit") }; TextButton({ delete("Note", index) }) { Text("Delete", color = Color(0xFFB54747)) } } }
            } }
            if (notes.isEmpty()) item { EmptyState("No notes yet", "Capture a useful idea from your next class.") }
        }
    }
}

@Composable
private fun CalendarPage(events: List<StudyEvent>, add: (String) -> Unit, edit: (String, Int) -> Unit, delete: (String, Int) -> Unit) {
    Column(Modifier.fillMaxSize()) {
        Row(Modifier.fillMaxWidth().padding(horizontal = 20.dp), verticalAlignment = Alignment.CenterVertically) { Column(Modifier.weight(1f)) { Text("September 2026", color = Ink, fontWeight = FontWeight.Bold, fontSize = 18.sp); Text("Exams, deadlines & plans", color = Muted, fontSize = 12.sp) }; Button({ add("Event") }, shape = RoundedCornerShape(14.dp)) { Text("+ Event") } }
        Card(Modifier.padding(20.dp).fillMaxWidth(), shape = RoundedCornerShape(20.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
            Column(Modifier.padding(14.dp)) {
                Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { listOf("M", "T", "W", "T", "F", "S", "S").forEach { Text(it, color = Muted, modifier = Modifier.padding(5.dp)) } }
                (0..4).forEach { week -> Row(Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.SpaceBetween) { (1..7).forEach { day -> val n = week * 7 + day - 1; if (n < 30) Surface(color = if (n + 1 == 29) Teal else Color.Transparent, shape = CircleShape, modifier = Modifier.size(34.dp)) { Box(contentAlignment = Alignment.Center) { Text("${n + 1}", color = if (n + 1 == 29) Color.White else Ink, fontSize = 12.sp) } } else Spacer(Modifier.size(34.dp)) } } }
            }
        }
        Row(Modifier.padding(horizontal = 20.dp), horizontalArrangement = Arrangement.spacedBy(14.dp)) { Legend("Exam", Gold); Legend("Deadline", Teal); Legend("Personal", Mint) }
        LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(10.dp)) {
            item { Text("UPCOMING", color = Muted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp) }
            items(events.withIndex().toList()) { (index, event) -> Card(shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) {
                Row(Modifier.fillMaxWidth().padding(14.dp), verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(10.dp).clip(CircleShape).background(eventColor(event.kind))); Column(Modifier.weight(1f).padding(start = 12.dp)) { Text(event.title, color = Ink, fontWeight = FontWeight.SemiBold); Text("${event.kind} · ${event.date}", color = Muted, fontSize = 12.sp) }; TextButton({ edit("Event", index) }) { Text("Edit") }; TextButton({ delete("Event", index) }) { Text("×", color = Color(0xFFB54747)) } }
            } }
            if (events.isEmpty()) item { EmptyState("No events planned", "Add exams, deadlines, or personal plans.") }
        }
    }
}

@Composable
private fun NotificationsPage() {
    var read by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().padding(20.dp)) {
        TextButton({ read = true }, modifier = Modifier.align(Alignment.End)) { Text("Mark all as read", color = Teal) }
        if (!read) listOf("Database midterm coming up", "Research outline due today", "You have 2 tasks to finish").forEachIndexed { index, title ->
            Card(Modifier.fillMaxWidth().padding(bottom = 10.dp), shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = if (index == 0) Color(0xFFEAF6F4) else Color.White)) {
                Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) { Text(listOf("◷", "!", "✓")[index], color = Teal, fontSize = 20.sp); Column(Modifier.padding(start = 12.dp)) { Text(title, color = Ink, fontWeight = FontWeight.SemiBold); Text(listOf("Exam reminder · Today, 9:15 AM", "Deadline reminder · Yesterday", "Task reminder · Sep 27")[index], color = Muted, fontSize = 12.sp) } }
            }
        } else EmptyState("You’re all caught up", "New reminders will show up here.")
    }
}

@Composable
private fun ProfilePage(navigate: (String) -> Unit, signOut: () -> Unit) {
    LazyColumn(contentPadding = PaddingValues(20.dp), verticalArrangement = Arrangement.spacedBy(14.dp)) {
        item { Card(shape = RoundedCornerShape(22.dp), colors = CardDefaults.cardColors(containerColor = Teal)) { Row(Modifier.fillMaxWidth().padding(20.dp), verticalAlignment = Alignment.CenterVertically) { Surface(color = Color.White.copy(alpha = .18f), shape = CircleShape, modifier = Modifier.size(64.dp)) { Box(contentAlignment = Alignment.Center) { Text("S", color = Color.White, fontSize = 27.sp, fontWeight = FontWeight.Bold) } }; Column(Modifier.padding(start = 14.dp)) { Text("Sam Student", color = Color.White, fontSize = 20.sp, fontWeight = FontWeight.Bold); Text("sam.student@university.edu", color = Color.White.copy(alpha = .8f), fontSize = 12.sp) } } } }
        item { Card(shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) { Column(Modifier.padding(16.dp)) { ProfileRow("University", "Northbridge University"); ProfileRow("Academic level", "Year 2 · Undergraduate"); ProfileRow("Speciality", "Computer Science") } } }
        item { Text("YOUR STUDY SPACE", color = Muted, fontSize = 11.sp, fontWeight = FontWeight.Bold, letterSpacing = 1.sp) }
        item { ProfileLink("Weekly timetable", "▦") { navigate("Timetable") } }
        item { ProfileLink("Personal notes", "✎") { navigate("Notes") } }
        item { ProfileLink("Notifications", "♧") { navigate("Notifications") } }
        item { ProfileLink("Edit profile", "⚙") { navigate("Edit profile") } }
        item { ProfileLink("Change password", "⌑") { navigate("Change password") } }
        item { OutlinedButton(signOut, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(14.dp)) { Text("Log out", color = Color(0xFFB54747)) } }
    }
}

@Composable
private fun EditProfilePage(onSave: () -> Unit) {
    var name by rememberSaveable { mutableStateOf("Sam Student") }
    var email by rememberSaveable { mutableStateOf("sam.student@university.edu") }
    var university by rememberSaveable { mutableStateOf("Northbridge University") }
    var level by rememberSaveable { mutableStateOf("Year 2 · Undergraduate") }
    var speciality by rememberSaveable { mutableStateOf("Computer Science") }
    var saved by remember { mutableStateOf(false) }
    Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TextField("Full name", name, { name = it })
        TextField("Email", email, { email = it })
        TextField("University", university, { university = it })
        TextField("Academic level", level, { level = it })
        TextField("Speciality", speciality, { speciality = it })
        if (saved) Text("Profile changes saved for this session.", color = Teal)
        Button(onClick = { if (name.isNotBlank() && email.contains("@")) { saved = true } }, modifier = Modifier.fillMaxWidth()) { Text("Save changes") }
        TextButton(onClick = onSave, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text("Back to profile", color = Teal) }
    }
}

@Composable
private fun ChangePasswordPage(onBack: () -> Unit) {
    var current by rememberSaveable { mutableStateOf("") }
    var newPassword by rememberSaveable { mutableStateOf("") }
    var confirm by rememberSaveable { mutableStateOf("") }
    var message by remember { mutableStateOf("") }
    Column(Modifier.fillMaxSize().padding(20.dp), verticalArrangement = Arrangement.spacedBy(12.dp)) {
        TextField("Current password", current, { current = it })
        TextField("New password", newPassword, { newPassword = it })
        TextField("Confirm new password", confirm, { confirm = it })
        if (message.isNotEmpty()) Text(message, color = Teal)
        Button(onClick = {
            message = if (current.isBlank() || newPassword.length < 6) "Enter your current password and a new password of at least 6 characters."
            else if (newPassword != confirm) "The new passwords do not match."
            else "Password updated for this demo session."
        }, modifier = Modifier.fillMaxWidth()) { Text("Update password") }
        TextButton(onClick = onBack, modifier = Modifier.align(Alignment.CenterHorizontally)) { Text("Back to profile", color = Teal) }
    }
}

@Composable
private fun ProfileRow(label: String, value: String) { Column(Modifier.padding(vertical = 7.dp)) { Text(label, color = Muted, fontSize = 12.sp); Text(value, color = Ink, fontWeight = FontWeight.Medium) } }

@Composable
private fun ProfileLink(label: String, icon: String, onClick: () -> Unit) { Card(Modifier.fillMaxWidth().clickable { onClick() }, shape = RoundedCornerShape(16.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) { Row(Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) { Text(icon, color = Teal, fontSize = 19.sp); Text(label, color = Ink, modifier = Modifier.weight(1f).padding(start = 12.dp)); Text("›", color = Muted) } } }

@Composable
private fun SectionHeader(title: String, action: String?, onClick: () -> Unit) { Row(Modifier.fillMaxWidth(), verticalAlignment = Alignment.CenterVertically) { Text(title, color = Ink, fontSize = 17.sp, fontWeight = FontWeight.Bold, modifier = Modifier.weight(1f)); if (action != null) Text(action, color = Teal, fontSize = 12.sp, modifier = Modifier.clickable { onClick() }) } }

@Composable
private fun StatCard(number: String, label: String, icon: String, modifier: Modifier = Modifier) { Card(modifier, shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = Color.White)) { Column(Modifier.padding(12.dp)) { Text(icon, color = Teal); Text(number, color = Ink, fontSize = 22.sp, fontWeight = FontWeight.Bold); Text(label, color = Muted, fontSize = 11.sp) } } }

@Composable
private fun QuickAction(icon: String, label: String, tint: Color, modifier: Modifier = Modifier, onClick: () -> Unit) { Card(modifier.clickable { onClick() }, shape = RoundedCornerShape(18.dp), colors = CardDefaults.cardColors(containerColor = tint)) { Column(Modifier.fillMaxWidth().padding(14.dp)) { Text(icon, color = Teal, fontSize = 20.sp); Spacer(Modifier.height(8.dp)); Text(label, color = Ink, fontWeight = FontWeight.SemiBold, fontSize = 12.sp) } } }

@Composable
private fun EmptyState(title: String, subtitle: String) { Column(Modifier.fillMaxWidth().padding(vertical = 38.dp), horizontalAlignment = Alignment.CenterHorizontally) { Text("✦", color = Mint, fontSize = 30.sp); Text(title, color = Ink, fontWeight = FontWeight.Bold); Text(subtitle, color = Muted, fontSize = 13.sp) } }

@Composable
private fun Legend(label: String, color: Color) { Row(verticalAlignment = Alignment.CenterVertically) { Box(Modifier.size(8.dp).clip(CircleShape).background(color)); Text(label, color = Muted, fontSize = 11.sp, modifier = Modifier.padding(start = 5.dp)) } }

private fun eventColor(kind: String): Color = when (kind) { "Exam" -> Gold; "Deadline" -> Teal; else -> Mint }

@Composable
private fun TextField(label: String, value: String, onValueChange: (String) -> Unit) { OutlinedTextField(value, onValueChange, label = { Text(label) }, singleLine = true, modifier = Modifier.fillMaxWidth(), shape = RoundedCornerShape(16.dp)) }

@Composable
private fun EntryDialog(type: String, initial: String, onDismiss: () -> Unit, onSave: (List<String>) -> Unit) {
    val labels = when (type) {
        "Course" -> listOf("Course name", "Professor", "Room", "Course type", "Schedule")
        "Task" -> listOf("Task title", "Associated course", "Due date", "Priority: Low / Medium / High", "Status: To Do / In Progress / Completed")
        "Note" -> listOf("Note title", "Associated course", "Note text")
        else -> listOf("Event title", "Date and time", "Type: Exam / Deadline / Personal")
    }
    val initialValues = initial.split('\n')
    val fields = remember(type, initial) { labels.mapIndexed { index, _ -> mutableStateOf(initialValues.getOrElse(index) { "" }) } }
    var error by remember { mutableStateOf("") }
    AlertDialog(onDismissRequest = onDismiss, title = { Text(if (initial.isEmpty()) "Add $type" else "Edit $type") }, text = {
        Column {
            labels.forEachIndexed { index, label -> OutlinedTextField(fields[index].value, { fields[index].value = it }, label = { Text(label) }, modifier = Modifier.fillMaxWidth().padding(vertical = 4.dp), maxLines = if (type == "Note" && index == 2) 4 else 1, shape = RoundedCornerShape(12.dp)) }
            if (error.isNotEmpty()) Text(error, color = Color(0xFFB54747), fontSize = 12.sp)
        }
    }, confirmButton = { TextButton(onClick = { if (fields.first().value.isBlank()) error = "Please enter a title." else onSave(fields.map { it.value }) }) { Text("Save", color = Teal) } }, dismissButton = { TextButton(onClick = onDismiss) { Text("Cancel") } })
}
