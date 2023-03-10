function getData(){
    var system24 = document.getElementById("use24Option");
    var today = new Date();
    var dd = String(today.getDate()).padStart(2, '0');
    var mm = String(today.getMonth() + 1).padStart(2, '0'); //January is 0!
    var yyyy = today.getFullYear();

    today = dd + '-' + mm + '-' + yyyy;

    var location = document.getElementById("locationText").value;

    api_url = 'https://api.aladhan.com/v1/timingsByAddress/' + today + '?address=' + location

    $.getJSON(api_url, function(data, status){
        var definedTimes = [
            "Fajr",
            "Sunrise",
            "Dhuhr",
            "Asr",
            "Maghrib",
            "Isha"
        ]
        var dataTimings = data['data']['timings'];
        var t_row = '';
        var nextPrayerName = "";
        var currentTime = new Date();
        var PrayerDate = new Date();
        // Getting next Prayer
        for (let key in dataTimings) {
            if(definedTimes.includes(key)){
                var prayerTime = dataTimings[key]
                prayerTime = prayerTime.split(":")
                PrayerDate.setHours(Number(prayerTime[0]),Number(prayerTime[1]))
                if(PrayerDate > currentTime){
                    nextPrayerName = key;
                    break;
                }
            }
        }
        if (nextPrayerName == ""){
            nextPrayerName = "Fajr"
        }
        // Populating data
        for (let key in dataTimings) {
            if(definedTimes.includes(key)){
                if (key == nextPrayerName){
                    t_row += '<tr class="Timings nextPrayer">';
                }else{
                    t_row += '<tr class="Timings">';
                }
                t_row += '<td>' + key + '</td>';
                if(system24.checked){
                    t_row += '<td>' + dataTimings[key] + '</td>';
                }else{
                    var convertedValue = convertTime(dataTimings[key]);
                    t_row += '<td>' + convertedValue + '</td>';
                }
                
                t_row += '</tr>';
            }
        };  
        $(".Timings").remove(); 
        $('#table').append(t_row);
        localStorage.setItem("location", location)
    });
}


$( document ).ready(function() {
    var input_text = document.getElementById("locationText");
    var system24 = document.getElementById("use24Option");

    input_text.addEventListener("keypress", function(event) {
    if (event.key === "Enter") {
        event.preventDefault();
        document.getElementById("getTimesButton").click();
    }
    });
    if (localStorage.getItem("24system") != null) {
        if(localStorage.getItem("24system") == 'false'){
            system24.checked = false
        }else{
            system24.checked = true
        }
    }else{
        localStorage.setItem("24system", true)
    }
    if (localStorage.getItem("location")) {
        input_text.value = localStorage.getItem("location");
        getData();
    }
    
});

function change24Option(){
    var system24 = document.getElementById("use24Option");
    localStorage.setItem("24system", system24.checked)
}

function convertTime(time){
    var PrayerDate = new Date();
    time = time.split(":")
    PrayerDate.setHours(Number(time[0]),Number(time[1]))
    return PrayerDate.toLocaleTimeString([],{hour12:true, hour: '2-digit', minute:'2-digit'})
}