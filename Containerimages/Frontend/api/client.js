//Url für die API
let statusAPIURL = "http://zuericloud.ch/api/status/all?apikey=508262b7-c962-41f5-9aca-85a41e45f930";

//Mit diesem Objekt können die Services bestimmt werden, die dargestellt werden
let services = {
    nextcloud: {
        identifier: "nextcloud",
        name: "Nextcloud",
        services: [
            "Nextcloud",
            "MySql",
            "Apache2",
            "PHP"
        ]
    },
    reverseproxy: {
        identifier: "reverseproxy",
        name: "NGINX Reverse Proxy",
        services: [
            "nginx"
        ]
    },
    mailserver: {
        identifier: "mailserver",
        name: "Postfix Mailserver",
        services: [
            "SMTP",
            "IMAP"
        ]
    },
    frontend: {
        identifier: "frontend",
        name: "Züri Cloud Startseite",
        services: [
            "Container",
        ]
    }
}

const apiStatusElementStatus = document.querySelector(".api-status__status");

function displayAPIStatus(error, ok) {
    if (error && ok == undefined)  {
        apiStatusElementStatus.textContent = ` Fehler mit API-Verbindung ${error}`;
    } else {
        apiStatusElementStatus.textContent = ` HTTP ${ok}`;
    }
}

async function getStatusInfo(url) {
    try {
        const response = await fetch(url, {
            method: 'GET',
            headers: {
                'Content-Type': 'application/json'
            },
        });
        //Catch fängt nur Fehler auf, die unterhalb Layer 7 liegen. 
        //Für HTTP 400 und 500 Codes muss dies mit response.ok (http code = 200-299) geprüft werden
        if (!response.ok) {
            throw new Error
        } else {
            displayAPIStatus(undefined, response.status)
            return response;
        }
    } catch (error) {
        displayAPIStatus(error, undefined)
        console.error(error);
    }
}

//Diese Funktionen stellt die JSON Daten im HTML dar. 
function renderStatusInfo(statusData) {
    //So sollen die übermittelnden JSON Daten strukturiert sein
    // let statusData = {
    //     identifier: nextcloud,
    //     services: {
    //         "Nextcloud": 1,
    //         "MySql": 1,
    //         "Apache2": 1,
    //         "PHP": 1
    //     }
    // }

    const allServiceStatusElements = document.querySelectorAll(".service-status__element");

    for(let i = 0; i < allServiceStatusElements.length; i++) {
        if (allServiceStatusElements[i].classList.contains(`service-status__element--${statusData.identifier}`)) {

            //Alte Table wird gelöscht
            const statusElementBody = document.querySelector(`.service-status__element--body--${statusData.identifier}`);
            const statusElementBodyTable = document.querySelector(`.service-status__element--body-table--${statusData.identifier}`);

            statusElementBody.removeChild(statusElementBodyTable);

            let serviceStatusDOMElementBodyTable = document.createElement("table");
            serviceStatusDOMElementBodyTable.classList.add("service-status__element--body-table");
            serviceStatusDOMElementBodyTable.classList.add(`service-status__element--body-table--${statusData.identifier}`);

            for(element in statusData.services) {
                let newTableRow = document.createElement("tr");
                let newTableDataName = document.createElement("td");
                let newTableDataValue = document.createElement("td");

                newTableDataName.textContent = element;
                
        
                if(statusData.services[element] === 1) {
                    newTableDataValue.textContent = "Online";
                    newTableDataValue.classList.add("online");
                } else {
                    newTableDataValue.textContent = "Offline";
                    newTableDataValue.classList.add("offline");
                }

                newTableRow.appendChild(newTableDataName);
                newTableRow.appendChild(newTableDataValue);

                serviceStatusDOMElementBodyTable.appendChild(newTableRow)
            }

            statusElementBody.appendChild(serviceStatusDOMElementBodyTable);
           break
        }
    }
}

const main = document.querySelector("main");

function renderDOMHTML(serviceidentifier, headertext, services) {
    
    let serviceStatusDOMElement = document.createElement("div");
    serviceStatusDOMElement.classList.add(`service-status__element`);
    serviceStatusDOMElement.classList.add(`service-status__element--${serviceidentifier}`);

    let serviceStatusDOMElementHeader = document.createElement("div");
    serviceStatusDOMElementHeader.classList.add("service-status__element--header");
    
    let serviceStatusDOMElementHeaderH = document.createElement("h2");
    serviceStatusDOMElementHeaderH.classList.add("service-status__element--header-text");
    serviceStatusDOMElementHeaderH.textContent = headertext;
    serviceStatusDOMElementHeader.appendChild(serviceStatusDOMElementHeaderH);

    let serviceStatusDOMElementBody = document.createElement("div");
    serviceStatusDOMElementBody.classList.add(`service-status__element--body--${serviceidentifier}`);
    let serviceStatusDOMElementBodyTable = document.createElement("table");
    serviceStatusDOMElementBodyTable.classList.add("service-status__element--body-table");
    serviceStatusDOMElementBodyTable.classList.add(`service-status__element--body-table--${serviceidentifier}`);
    serviceStatusDOMElementBody.appendChild(serviceStatusDOMElementBodyTable);

    //Generiert Tabelle beim laden der Website
    services.forEach(element => {
        let newTableRow = document.createElement("tr");
        let nameTableData = document.createElement("td");
        let statusTableData = document.createElement("td");
        statusTableData.classList.add("table-service-status");
        nameTableData.textContent = element;
        statusTableData.textContent = "not fetched";
        newTableRow .appendChild(nameTableData);
        newTableRow .appendChild(statusTableData);
        serviceStatusDOMElementBodyTable.appendChild(newTableRow);
    })
    
    serviceStatusDOMElement.appendChild(serviceStatusDOMElementHeader);
    serviceStatusDOMElement.appendChild(serviceStatusDOMElementBody);

    main.appendChild(serviceStatusDOMElement);
}

//Sobald das Dokument geladen ist, wird der Server nach Informationen angefragt
const apiStatusLastFetch = document.querySelector(".api-status__lastfetch");

window.addEventListener("load", () => {
    //Die Seite wird dynamisch nach dem "services" Objekt generiert
    for(element in services) {
        renderDOMHTML(services[element].identifier ,services[element].name, services[element].services);
    }

    let interval = setInterval(() => {
        getStatusInfo(statusAPIURL) //Asynchrone Funktion gibt einen JavaScript Promise zurück
        .then((response) => response.json()) //Wenn der Promise status "resolved" hat, wird der Body des HTTP Response in lesbarers JavaScript Objekt umgewandelt
        .then((data) => {

            for(element in data) {
                renderStatusInfo(data[element]);
            }

            //renderStatusInfo(data)
            let date = new Date()
            var time = date.getHours() + ":" + date.getMinutes() + ":" + date.getSeconds();
            apiStatusLastFetch.textContent = time; //Gibt die Informationen weiter an das Frontend
        })
        .catch((error) => {
            console.error(error)
        }); 
    }, 5000);

});
