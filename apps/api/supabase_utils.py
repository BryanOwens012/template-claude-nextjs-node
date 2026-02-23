"""
Supabase utility functions for common operations.

This module provides helper functions for interacting with Supabase,
including common CRUD operations and query patterns.
"""

from typing import Any, Dict, List, Optional
from supabase import Client
from fastapi import HTTPException


def get_client_or_raise(client: Optional[Client]) -> Client:
    """
    Check if Supabase client is available, raise HTTP exception if not.

    Args:
        client: Supabase client instance

    Returns:
        The client if available

    Raises:
        HTTPException: If client is not available
    """
    if not client:
        raise HTTPException(
            status_code=503,
            detail="Supabase is not available. Check server configuration.",
        )
    return client


async def select_all(
    client: Optional[Client], table: str, limit: int = 100
) -> List[Dict[str, Any]]:
    """
    Select all records from a table.

    Args:
        client: Supabase client instance
        table: Table name
        limit: Maximum number of records to return (default: 100)

    Returns:
        List of records

    Raises:
        HTTPException: If query fails
    """
    client = get_client_or_raise(client)

    try:
        response = client.table(table).select("*").limit(limit).execute()
        return response.data
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to query {table}: {str(e)}"
        )


async def select_by_id(
    client: Optional[Client], table: str, id_value: Any, id_column: str = "id"
) -> Optional[Dict[str, Any]]:
    """
    Select a single record by ID.

    Args:
        client: Supabase client instance
        table: Table name
        id_value: Value of the ID to search for
        id_column: Name of the ID column (default: "id")

    Returns:
        Record if found, None otherwise

    Raises:
        HTTPException: If query fails
    """
    client = get_client_or_raise(client)

    try:
        response = (
            client.table(table)
            .select("*")
            .eq(id_column, id_value)
            .limit(1)
            .execute()
        )
        return response.data[0] if response.data else None
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to query {table}: {str(e)}"
        )


async def insert_record(
    client: Optional[Client], table: str, data: Dict[str, Any]
) -> Dict[str, Any]:
    """
    Insert a new record into a table.

    Args:
        client: Supabase client instance
        table: Table name
        data: Record data to insert

    Returns:
        Inserted record with generated fields (e.g., id, created_at)

    Raises:
        HTTPException: If insert fails
    """
    client = get_client_or_raise(client)

    try:
        response = client.table(table).insert(data).execute()
        return response.data[0] if response.data else {}
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to insert into {table}: {str(e)}"
        )


async def update_record(
    client: Optional[Client],
    table: str,
    id_value: Any,
    data: Dict[str, Any],
    id_column: str = "id",
) -> Dict[str, Any]:
    """
    Update a record by ID.

    Args:
        client: Supabase client instance
        table: Table name
        id_value: Value of the ID to update
        data: Updated record data
        id_column: Name of the ID column (default: "id")

    Returns:
        Updated record

    Raises:
        HTTPException: If update fails
    """
    client = get_client_or_raise(client)

    try:
        response = (
            client.table(table)
            .update(data)
            .eq(id_column, id_value)
            .execute()
        )
        if not response.data:
            raise HTTPException(status_code=404, detail=f"Record not found in {table}")
        return response.data[0]
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to update {table}: {str(e)}"
        )


async def delete_record(
    client: Optional[Client],
    table: str,
    id_value: Any,
    id_column: str = "id",
) -> bool:
    """
    Delete a record by ID.

    Args:
        client: Supabase client instance
        table: Table name
        id_value: Value of the ID to delete
        id_column: Name of the ID column (default: "id")

    Returns:
        True if record was deleted

    Raises:
        HTTPException: If delete fails
    """
    client = get_client_or_raise(client)

    try:
        response = (
            client.table(table)
            .delete()
            .eq(id_column, id_value)
            .execute()
        )
        return len(response.data) > 0
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to delete from {table}: {str(e)}"
        )


async def query_with_filter(
    client: Optional[Client],
    table: str,
    filters: Dict[str, Any],
    limit: int = 100,
    order_by: Optional[str] = None,
    ascending: bool = True,
) -> List[Dict[str, Any]]:
    """
    Query table with multiple filters.

    Args:
        client: Supabase client instance
        table: Table name
        filters: Dictionary of column:value pairs to filter by
        limit: Maximum number of records to return (default: 100)
        order_by: Column to order by (optional)
        ascending: Sort order (default: True)

    Returns:
        List of matching records

    Raises:
        HTTPException: If query fails

    Example:
        records = await query_with_filter(
            client,
            "users",
            {"role": "admin", "active": True},
            order_by="created_at",
            ascending=False
        )
    """
    client = get_client_or_raise(client)

    try:
        query = client.table(table).select("*")

        # Apply filters
        for column, value in filters.items():
            query = query.eq(column, value)

        # Apply ordering
        if order_by:
            query = query.order(order_by, desc=not ascending)

        # Apply limit
        query = query.limit(limit)

        response = query.execute()
        return response.data
    except Exception as e:
        raise HTTPException(
            status_code=500, detail=f"Failed to query {table}: {str(e)}"
        )


# Example usage in your API routes:
#
# from main import supabase_client
# from supabase_utils import select_all, insert_record
#
# @app.get("/api/users")
# async def get_users():
#     users = await select_all(supabase_client, "users", limit=50)
#     return {"users": users}
#
# @app.post("/api/users")
# async def create_user(user_data: dict):
#     new_user = await insert_record(supabase_client, "users", user_data)
#     return {"user": new_user}
