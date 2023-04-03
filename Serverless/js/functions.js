function getData(){
    // var loader = document.getElementById("loading");
    $("#loading").show()
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
                PrayerDate.setHours(Number(prayerTime[0]),Number(prayerTime[1]),0)
                if(PrayerDate > currentTime){
                    nextPrayerName = key;
                    nextPrayerTime = PrayerDate.getTime();
                    break;
                }
            }
        }
        if (nextPrayerName == ""){
            nextPrayerName = "Fajr"
            var prayerTime = dataTimings["Fajr"]
            prayerTime = prayerTime.split(":")
            PrayerDate.setHours(Number(prayerTime[0]),Number(prayerTime[1]),0)
            PrayerDate.setDate(currentTime.getDate() + 1)
            nextPrayerTime = PrayerDate.getTime();
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
        $("#loading").hide()
        gregorian_month_name = data['data']['date']["gregorian"]["month"]["en"]
        hijri_month_name = data['data']['date']["gregorian"]["date"]
        gregorian_date = data['data']['date']["hijri"]["month"]["en"]
        hijri_date = data['data']['date']["hijri"]["date"]
        $("#current_date_month").text(gregorian_month_name)
        $("#current_date_text").text(hijri_month_name)
        $("#current_hijri_month").text(gregorian_date)
        $("#current_hijri_text").text(hijri_date)
        // $("#current_date_text").text(currentTime.toLocaleDateString('en-us',{weekday:"long", year:"numeric", month:"short", day:"numeric"}))
        // $("#current_hijri_text").text(currentTime.toLocaleDateString('en-TN-u-ca-islamic',{year:"numeric", month:"long", day:"numeric"}))
        checkTimeLeft()
    });
    
}

var nextPrayerTime = null
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

let interval = null

function checkTimeLeft(){
    if (nextPrayerTime == null){
        return 
    }
    interval = setInterval(calculateTimeLeft, 1000);
}

function calculateTimeLeft(){
    var currentTime = new Date().getTime();
    if (nextPrayerTime < currentTime) {
        clearInterval(interval);
        location.reload();
        return;
      }
    var difference = nextPrayerTime - currentTime;
    let hoursValue = Math.floor(
      (difference % (1000 * 60 * 60 * 24)) / (1000 * 60 * 60)
    )
      .toString()
      .padStart(2, "0");
    let minutesValue = Math.floor((difference % (1000 * 60 * 60)) / (1000 * 60))
      .toString()
      .padStart(2, "0");
    let secondsValue = Math.floor((difference % (1000 * 60)) / 1000)
      .toString()
      .padStart(2, "0");

    document.getElementById('hoursLeft').innerText = hoursValue;
    document.getElementById('minutesLeft').innerText = minutesValue;
    document.getElementById('secondsLeft').innerText = secondsValue;
}

  