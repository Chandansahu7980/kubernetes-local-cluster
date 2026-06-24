<?php
include 'db.php';
$id = $_GET['id'];
if ($_SERVER['REQUEST_METHOD'] === 'POST') {
    $name  = $_POST['name'];
    $email = $_POST['email'];
    $sql = "UPDATE users
            SET name='$name', email='$email'
            WHERE id=$id";
    if ($conn->query($sql)) {
        header("Location: index.php");
        exit();
    } else {
        echo "Update failed: " . $conn->error;
    }
}
$result = $conn->query("SELECT * FROM users WHERE id=$id");
$row = $result->fetch_assoc();
?>
<h2>Edit User</h2>
<form method="post">
    Name:
    <input type="text" name="name" value="<?= $row['name'] ?>"><br><br>

    Email:
    <input type="text" name="email" value="<?= $row['email'] ?>"><br><br>
    <button type="submit">Update</button>
</form>