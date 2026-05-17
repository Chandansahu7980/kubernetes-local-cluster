<?php
include 'db.php';

if ($_POST) {
    $name = $_POST['name'];
    $email = $_POST['email'];

    $conn->query("INSERT INTO users(name,email) VALUES('$name','$email')");

    header("Location: index.php");
}
?>
<h2>Create User</h2>
<form method="post">
    Name: <input type="text" name="name"><br><br>
    Email: <input type="text" name="email"><br><br>

    <button type="submit">Save</button>
</form>