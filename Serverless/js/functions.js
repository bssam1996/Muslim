function getData(){
    var today = new Date();
    var dd = String(today.getDate()).padStart(2, '0');
    var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
    var yyyy = today.getFullYear();

    today = dd + '-' + mm + '-' + yyyy;

    var location = document.getElementById("locationText").value;

    api_url = 'https://api.aladhan.com/v1/timingsByAddress/' + today + '?address=' + location

    $.getJSON(api_url, function(data, status){
        var myList = data['data']['timings'];
        var student = '';
        for (let key in myList) {
            student += '<tr class="Timings">';
            student += '<td>' + key + '</td>';
            student += '<td>' + myList[key] + '</td>';
            student += '</tr>';
        };  
        $(".Timings").remove(); 
        $('#table').append(student);
        localStorage.setItem("location", location)
    });
}


$( document ).ready(function() {
    var input_text = document.getElementById("locationText");
    input_text.addEventListener("keypress", function(event) {
    if (event.key === "Enter") {
        event.preventDefault();
        document.getElementById("getTimesButton").click();
    }
    });
    if (localStorage.getItem("location")) {
        input_text.value = localStorage.getItem("location")
        getData();
      }
});