const counter = document.querySelector(".counter-number");

async function updateCounter() {
    try {
        let response = await fetch("https://feecxo7jo2hwex7oasjftbmo5a0beufd.lambda-url.us-east-1.on.aws/");

        if (!response.ok) {
            throw new Error(`HTTP error! Status: ${response.status}`);
        }

        let data = await response.json();
        counter.innerHTML = `You are viewer: ${data}`;
    } catch (error) {
        console.error('Error in updateCounter:', error);
    }
}

updateCounter();