const counter = document.querySelector(".counter-number");
async function updateCounter() {
  try {
    const response = await fetch("https://e3ttrvtvipqlvarijvbesnn7um0kcnix.lambda-url.us-east-1.on.aws/");
    if (!response.ok) {
      throw new Error(`HTTP error! Status: ${response.status}`);
    }
    const data = await response.json();
    counter.innerHTML = `You are viewer: ${data}`;
  } catch (error) {
    console.error('Error in updateCounter:', error);
  }
}
updateCounter();

