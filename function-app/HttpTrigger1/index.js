module.exports = async function (context, req) {
    context.log('JavaScript HTTP trigger function processed a request.');

    const htmlResponse = `
        <!DOCTYPE html>
        <html lang="en">
        <head>
            <meta charset="UTF-8">
            <meta name="viewport" content="width=device-width, initial-scale=1.0">
            <title>App Service Hosted Function App</title>
            <style>
                body {
                    margin: 0;
                    font-family: Arial, Helvetica, sans-serif;
                    background: linear-gradient(135deg, #ff4c4c, #ff1a1a);
                    height: 100vh;
                    display: flex;
                    flex-direction: column;
                }
                header {
                    background: rgba(0, 0, 0, 0.25);
                    padding: 15px 30px;
                    color: white;
                    font-size: 1.2rem;
                    font-weight: bold;
                    text-align: left;
                    box-shadow: 0 2px 6px rgba(0,0,0,0.3);
                }
                main {
                    flex: 1;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                }
                .banner {
                    background: white;
                    color: #d40000;
                    padding: 30px 60px;
                    border-radius: 12px;
                    font-size: 1.8rem;
                    font-weight: bold;
                    box-shadow: 0 6px 12px rgba(0,0,0,0.3);
                    text-align: center;
                }
            </style>
        </head>
        <body>
            <header>App Service Hosted Function App</header>
            <main>
                <div class="banner">Hello from an App Service Hosted Function App!</div>
            </main>
        </body>
        </html>
    `;

    context.res = {
        headers: { "Content-Type": "text/html" },
        body: htmlResponse
    };
};
