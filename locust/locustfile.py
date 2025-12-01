from locust import HttpUser, task, between, events
import random
import json
import time

class OrderUser(HttpUser):
    wait_time = between(0.1, 0.5)

    @task
    def create_async_order(self):
        order = {
            "customer_id": random.randint(1, 1000),
            "items": [
                {
                    "product_id": f"item-{random.randint(1, 100)}",
                    "quantity": random.randint(1, 5),
                    "price": round(random.uniform(10.0, 100.0), 2)
                }
            ]
        }
        
        start_time = time.time()
        with self.client.post(
            "/orders/async",
            json=order,
            catch_response=True
        ) as response:
            response_time = (time.time() - start_time) * 1000  # Convert to ms
            if response.status_code == 202:
                response.success()
                # Log response time for analysis
                self.environment.events.request.fire(
                    request_type="POST",
                    name="/orders/async",
                    response_time=response_time,
                    response_length=len(response.content),
                    exception=None,
                    context={}
                )
            else:
                response.failure(f"Got status code {response.status_code}")